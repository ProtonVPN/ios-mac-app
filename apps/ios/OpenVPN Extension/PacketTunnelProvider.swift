//
//  PacketTunnelProvider.swift
//  ProtonVPN - Created on 29.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import TunnelKitOpenVPNAppExtension
import TunnelKitOpenVPN

import NetworkExtension
import Dependencies
import NEHelper
import VPNShared
import Timer
import LocalFeatureFlags
import DictionaryCoder

class PacketTunnelProvider: OpenVPNTunnelProvider, ExtensionAPIServiceDelegate {

    private var timerFactory: TimerFactory!
    private var appInfo: AppInfo
    private var apiService: ExtensionAPIService!
    private var certificateRefreshManager: ExtensionCertificateRefreshManager!
    private let vpnAuthenticationStorage: VpnAuthenticationStorage
    private var killSwitchSettingObservation: NSKeyValueObservation!
    // ExtensionAPIServiceDelegate
    internal var dataTaskFactory: DataTaskFactory!
    var transport: VPNShared.WireGuardTransport? // Used only on WireGuard

    var tunnelProviderProtocol: NETunnelProviderProtocol? {
        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return tunnelProviderProtocol
    }

    // This method is overridden to put key and certificate into config from inside NE without
    // changing the code of TunnelKit.
    override var protocolConfiguration: NEVPNProtocol {
        guard isEnabled(OpenVPNFeature.iosCertificates) else {
            return super.protocolConfiguration
        }
        guard let tunnelProviderProtocol = super.protocolConfiguration as? NETunnelProviderProtocol else {
            log.error("ProtocolConfiguration not set")
            return super.protocolConfiguration
        }

        tunnelProviderProtocol.username = nil // No need for a username inside NE
        let providerConfigDict = tunnelProviderProtocol.providerConfiguration ?? [:]

        let ovpnConfig: OpenVPN.Configuration
        do {
            ovpnConfig = try DictionaryDecoder().decode(OpenVPN.Configuration.self, from: providerConfigDict)
        } catch {
            log.error("Can't parse OpenVPN config from given NETunnelProviderProtocol: \(error)")
            return super.protocolConfiguration
        }

        let backup = tunnelProviderProtocol.backupCustomSettings()
        var ovpnBuilder = ovpnConfig.builder()

        // Next two sets are the essence of this method and why it exists: put key and certificate into the config
        if let keys = self.vpnAuthenticationStorage.getStoredKeys() {
            ovpnBuilder.clientKey = OpenVPN.CryptoContainer(pem: keys.privateKey.derRepresentation) // ed25519
        }
        if let certificate = self.vpnAuthenticationStorage.getStoredCertificate() {
            ovpnBuilder.clientCertificate = OpenVPN.CryptoContainer(pem: certificate.certificate)
        }

        do {
            let updatedProviderConfigDict = try OpenVPN.ProviderConfiguration(
                "ProtonVPN.OpenVPN",
                appGroup: AppConstants.AppGroups.main,
                configuration: ovpnBuilder.build()
            )
                .asTunnelProtocol(withBundleIdentifier: Bundle.main.bundleIdentifier!, extra: nil)
                .providerConfiguration

            tunnelProviderProtocol.providerConfiguration = updatedProviderConfigDict
        } catch {
            log.error("Couldn't update provider config: \(error)")
        }

        tunnelProviderProtocol.restoreCustomSettingsFrom(backup: backup)

        return tunnelProviderProtocol
    }

    override init() {
        AppContext.default = .openVpnExtension

        vpnAuthenticationStorage = VpnAuthenticationKeychain(accessGroup: OpenVPNConstants.keychainAccessGroup,
                                                             vpnKeysGenerator: ExtensionVPNKeysGenerator())

        appInfo = AppInfoImplementation()

        super.init()
        setupLogging()
        setLocalFeatureFlagOverrides(tunnelProviderProtocol?.featureFlagOverrides)

        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "11 minutes"
        #endif

        guard isEnabled(OpenVPNFeature.iosCertificates) else {
            return
        }

        setDataTaskFactory(sendThroughTunnel: false) // This will be changed after we connect

        timerFactory = TimerFactoryImplementation()
        let authKeychain = AuthKeychain.default
        apiService = ExtensionAPIService(timerFactory: timerFactory,
                                         keychain: authKeychain,
                                         appInfo: appInfo,
                                         atlasSecret: ObfuscatedConstants.atlasSecret)
        apiService.delegate = self

        certificateRefreshManager = ExtensionCertificateRefreshManager(apiService: apiService,
                                                                       timerFactory: timerFactory,
                                                                       vpnAuthenticationStorage: vpnAuthenticationStorage,
                                                                       keychain: authKeychain)

    }

    deinit {
        log.info("PacketTunnelProvider deinited")
    }

    override open func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        log.info("Start tunnel")
        guard isEnabled(OpenVPNFeature.iosCertificates) else {
            super.startTunnel(options: options, completionHandler: completionHandler)
            return
        }
        // First make sure we have a certificate, because it's needed by OpenVPN
        self.certificateRefreshManager.checkRefreshCertificateNow(features: nil, completion: { result in
            log.debug("Certificate check before connection: \(result)")

            super.startTunnel(options: options) { error in
                self.connectionEstablished(newVpnCertificateFeatures: nil)
                completionHandler(error)
            }
        })
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        super.sleep {
            log.info("sleep()")
            self.certificateRefreshManager.suspend {
                completionHandler()
            }
        }
    }

    override func wake() {
        super.wake()
        log.info("wake()")
        certificateRefreshManager.start { }
    }

    // MARK: - Data Task Factory

    /// NetworkExtension appears to have a bug where connections sent through the tunnel time out
    /// if the user is using KillSwitch (i.e., `includeAllNetworks`). Ironically, the best thing for
    /// this is to *not* send API requests through the VPN if the user has opted for KillSwitch.
    private func setDataTaskFactoryAccordingToKillSwitchSettings() {
        guard !self.protocolConfiguration.includeAllNetworks else {
            setDataTaskFactory(sendThroughTunnel: false)
            return
        }

        setDataTaskFactory(sendThroughTunnel: true)
    }

    private func setDataTaskFactory(sendThroughTunnel: Bool) {
        log.debug("Routing API requests through \(sendThroughTunnel ? "tunnel" : "URLSession").")

        dataTaskFactory = !sendThroughTunnel ?
            URLSession.shared :
            ConnectionTunnelDataTaskFactory(provider: self,
                                            timerFactory: timerFactory)
    }

    // MARK: -

    private func connectionEstablished(newVpnCertificateFeatures: VPNConnectionFeatures?) {
        setDataTaskFactoryAccordingToKillSwitchSettings()

        killSwitchSettingObservation = observe(\.protocolConfiguration.includeAllNetworks) { [unowned self] _, _ in
            log.debug("Kill Switch configuration changed.")
            self.setDataTaskFactoryAccordingToKillSwitchSettings()
        }

        if let newVpnCertificateFeatures = newVpnCertificateFeatures {
            log.debug("Connection restarted with another server. Will regenerate certificate.")
            certificateRefreshManager.checkRefreshCertificateNow(features: newVpnCertificateFeatures, userInitiated: true) { result in
                log.info("New certificate (after reconnection) result: \(result)", category: .userCert)
                self.certificateRefreshManager.start { }
            }
        } else { // New connection
            certificateRefreshManager.start { }
        }
    }

    // MARK: - Messages

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard isEnabled(OpenVPNFeature.iosCertificates) else {
            super.handleAppMessage(messageData, completionHandler: completionHandler)
            return
        }
        do {
            let message = try WireguardProviderRequest.decode(data: messageData)
            log.debug("HandleAppMessage: \(message)")
            handleProviderMessage(message) { response in
                completionHandler?(response.asData)
            }
        } catch {
            log.debug("App message decode error: \(error). Will try original OpenVPN message handler.")
            super.handleAppMessage(messageData, completionHandler: completionHandler)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func handleProviderMessage(_ message: WireguardProviderRequest,
                                       completionHandler: ((WireguardProviderRequest.Response) -> Void)?) {
        switch message {
        case .getRuntimeTunnelConfiguration:
            log.info("Unhandled message: getRuntimeTunnelConfiguration")

        case .flushLogsToFile:
            log.info("Unhandled message: flushLogsToFile")

        case let .setApiSelector(selector, sessionCookie):
            log.info("Handle message: setApiSelector", category: .userCert)
            certificateRefreshManager.newSession(withSelector: selector, sessionCookie: sessionCookie) { result in
                switch result {
                case .success:
                    completionHandler?(.ok(data: nil))
                case .failure(let error):
                    completionHandler?(.error(message: String(describing: error)))
                }
            }
        case .refreshCertificate(let features):
            log.info("Handle message: refreshCertificate")
            certificateRefreshManager.checkRefreshCertificateNow(features: features, userInitiated: true) { result in
                switch result {
                case .success:
                    completionHandler?(.ok(data: nil))
                case .failure(let error):
                    switch error {
                    case .sessionExpiredOrMissing:
                        completionHandler?(.errorSessionExpired)
                    case .needNewKeys:
                        completionHandler?(.errorNeedKeyRegeneration)
                    case .tooManyCertRequests(let retryAfter):
                        if let retryAfter = retryAfter {
                            completionHandler?(.errorTooManyCertRequests(retryAfter: Int(retryAfter)))
                        } else {
                            completionHandler?(.errorTooManyCertRequests(retryAfter: nil))
                        }
                    default:
                        completionHandler?(.error(message: String(describing: error)))
                    }
                }
            }
        case .cancelRefreshes:
            log.info("Handle message: cancelRefreshes")
            certificateRefreshManager.stop {
                completionHandler?(.ok(data: nil))
            }
        case .restartRefreshes:
            log.info("Handle message: restartRefreshes")
            certificateRefreshManager.start {
                completionHandler?(.ok(data: nil))
            }
        case .getCurrentLogicalAndServerId:
            // Handle when auto reconnect will be implemented
            log.info("Unhandled message: getCurrentLogicalAndServerId")
        }
    }

}
