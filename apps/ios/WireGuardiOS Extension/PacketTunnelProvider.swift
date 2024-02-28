//
//  PacketTunnelProvider.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import os
import Logging

import WireGuardKit

import Domain
import ExtensionIPC
import LocalFeatureFlags
import Timer
import VPNShared
import NEHelper

class PacketTunnelProvider: NEPacketTunnelProvider, ExtensionAPIServiceDelegate {
    private var timerFactory: TimerFactory!
    private var appInfo: AppInfo
    private var certificateRefreshManager: ExtensionCertificateRefreshManager!
    private var serverStatusRefreshManager: ServerStatusRefreshManager!
    private var killSwitchSettingObservation: NSKeyValueObservation!
    private let vpnAuthenticationStorage: VpnAuthenticationStorageSync

    private var currentWireguardServer: StoredWireguardConfig?
    // Currently connected logical server id
    private var connectedLogicalId: String?
    // Currently connected server ip id
    private var connectedIpId: String?

    var tunnelProviderProtocol: NETunnelProviderProtocol? {
        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }

        return tunnelProviderProtocol
    }

    public var dataTaskFactory: DataTaskFactory!

    public var transport: WireGuardTransport? {
        guard let socketType = self.tunnelProviderProtocol?.wgProtocol else {
            return nil
        }

        return WireGuardTransport(rawValue: socketType) ?? .udp
    }

    private var shouldStartServerRefreshOnWake: Bool {
        isEnabled(VpnReconnectionFeatureFlag())
        && self.connectedIpId != nil
        && self.connectedLogicalId != nil
    }

    override init() {
        AppContext.default = .wireGuardExtension

        vpnAuthenticationStorage = VpnAuthenticationKeychain(accessGroup: WGConstants.keychainAccessGroup,
                                                             vpnKeysGenerator: ExtensionVPNKeysGenerator())

        appInfo = AppInfoImplementation()

        let authKeychain = AuthKeychain.default

        super.init()

        setupLogging()
        wg_log(.info, message: "PacketTunnelProvider init (processID: \(ProcessInfo().processIdentifier))")

        self.timerFactory = TimerFactoryImplementation()

        killSwitchSettingObservation = observe(\.protocolConfiguration.includeAllNetworks) { [unowned self] _, _ in
            wg_log(.info, message: "Kill Switch configuration changed.")
            self.setDataTaskFactoryAccordingToKillSwitchSettings()
        }
        self.setDataTaskFactory(sendThroughTunnel: true)

        let apiService = ExtensionAPIService(timerFactory: timerFactory,
                                             keychain: authKeychain,
                                             appInfo: appInfo,
                                             atlasSecret: ObfuscatedConstants.atlasSecret)

        certificateRefreshManager = ExtensionCertificateRefreshManager(apiService: apiService,
                                                                       timerFactory: timerFactory,
                                                                       vpnAuthenticationStorage: vpnAuthenticationStorage,
                                                                       keychain: authKeychain)

        serverStatusRefreshManager = ServerStatusRefreshManager(apiService: apiService,
                                                                timerFactory: timerFactory)

        apiService.delegate = self
        serverStatusRefreshManager.delegate = self
    }
    
    deinit {
        wg_log(.info, message: "PacketTunnelProvider deinited (processID: \(ProcessInfo().processIdentifier))")
    }

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
        wg_log(.info, message: "Routing API requests through \(sendThroughTunnel ? "tunnel" : "URLSession").")

        dataTaskFactory = !sendThroughTunnel ?
                URLSession.shared :
                ConnectionTunnelDataTaskFactory(provider: self,
                                                timerFactory: timerFactory)
    }

    private func connectionEstablished(newVpnCertificateFeatures: VPNConnectionFeatures?) {
        if let newVpnCertificateFeatures = newVpnCertificateFeatures {
            log.debug("Connection restarted with another server. Will regenerate certificate.")
            certificateRefreshManager.checkRefreshCertificateNow(features: newVpnCertificateFeatures, userInitiated: true) { result in
                log.info("New certificate (after reconnection) result: \(result)", category: .userCert)
                self.certificateRefreshManager.start { }
            }
        } else { // New connection
            certificateRefreshManager.start { }
        }

        #if CHECK_CONNECTIVITY
        self.startTestingConnectivity()
        #endif

        guard let connectedLogicalId, let connectedIpId else {
            wg_log(.info, message: "Server ID wasn't set on tunnel start, likely updated while in the background. Won't start server status refresh manager.")
            return
        }

        wg_log(.info, message: "Starting server status refresh manager with logical \(connectedLogicalId) and server \(connectedIpId).")
        if isEnabled(VpnReconnectionFeatureFlag()) {
            serverStatusRefreshManager.updateConnectedIds(logicalId: connectedLogicalId, serverId: connectedIpId)
            serverStatusRefreshManager.start { }
        } else {
            log.debug("Maintenance check disabled", category: .connection)
        }
    }

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(.info, message: message)
        }
    }()

    func restartTunnel(with logical: ServerStatusRequest.Logical) {
        log.info("Restarting tunnel with new logical server: \(logical.id)", category: .connection)
        guard let currentWireguardServer, let transport else {
            log.error("API said to reconnect, but we haven't connected to a server yet?", category: .connection)
            return
        }

        guard let (server, entryIp) = logical.servers
            .filter({ !$0.underMaintenance })
            .compactMap({ (server: ServerStatusRequest.Server) -> (ServerStatusRequest.Server, String)? in
                guard let entryIp = server.entryIp(using: .wireGuard(transport)) else { return nil }
                return (server, entryIp)
            })
            .randomElement() else {
            log.error("No alternative server found for reconnection", category: .connection)
            return
        }

        log.info("Stopping tunnel and reconnecting to \(server.domain)", category: .connection)

        stopTunnel(with: .superceded) {
            let errorNotifier = ErrorNotifier(activationAttemptId: nil)

            self.currentWireguardServer = currentWireguardServer
                .withNewServerPublicKey(server.x25519PublicKey,
                                        andEntryServerAddress: entryIp)

            self.connectedLogicalId = logical.id
            self.connectedIpId = server.id

            // Update certificate features after connection is established
            let currentFeatures = self.vpnAuthenticationStorage.getStoredCertificateFeatures()
            let newVpnCertificateFeatures = currentFeatures?.copyWithChanged(bouncing: server.label)

            self.startTunnelWithStoredConfig(errorNotifier: errorNotifier, newVpnCertificateFeatures: newVpnCertificateFeatures) { error in
                if let error = error {
                    log.error("Error restarting tunnel \(error)", category: .connection)
                }

                log.info("Reconnected successfully to \(server.domain) (\(server.id)", category: .connection)
            }
        }
    }

    /// Actually start a tunnel
    /// - Parameter newVpnCertificateFeatures: If not nil, will generate new certificate after connecting to the server and before starting certificate
    /// refresh manager. On new connection nil should be used not to regenerate current certificate.
    private func startTunnelWithStoredConfig(errorNotifier: ErrorNotifier, newVpnCertificateFeatures: VPNConnectionFeatures?, completionHandler: @escaping (Error?) -> Void) {
        guard let storedConfig = currentWireguardServer else {
            wg_log(.error, message: "Current wireguard server not set; not starting tunnel")
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in \(#function) guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        guard let transport else {
            wg_log(.info, message: "Error in \(#function) guard 2: missing socket type")
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: storedConfig.asWireguardConfiguration()) else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in \(#function) guard 3: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        startTunnelWithConfiguration(
            tunnelConfiguration,
            errorNotifier: errorNotifier,
            newVpnCertificateFeatures: newVpnCertificateFeatures,
            transport: transport,
            completionHandler: completionHandler
        )
    }

    private func startTunnelWithConfiguration(
        _ tunnelConfiguration: TunnelConfiguration,
        errorNotifier: ErrorNotifier,
        newVpnCertificateFeatures: VPNConnectionFeatures?,
        transport: WireGuardTransport?,
        completionHandler: @escaping (Error?) -> Void) {

        let transport = transport ?? .udp
        // Start the tunnel
        adapter.start(tunnelConfiguration: tunnelConfiguration, socketType: transport.rawValue) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                wg_log(.info, message: "Tunnel interface is \(interfaceName)")

                completionHandler(nil)
                self.connectionEstablished(newVpnCertificateFeatures: newVpnCertificateFeatures)
                return
            }

            switch adapterError {
            case .cannotLocateTunnelFileDescriptor:
                wg_log(.error, staticMessage: "Starting tunnel failed: could not determine file descriptor")
                errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
                errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
                completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(errorCode)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                completionHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                wg_log(.error, message: "Starting tunnel failed with invalidState")
                // Must never happen
                fatalError()
            }
        }
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        setDataTaskFactoryAccordingToKillSwitchSettings()

        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "30 minutes"
        #endif

        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly" : "app"))
        flushLogsToFile() // Prevents empty logs in the app during the first WG connection

        guard let keychainConfigData = tunnelProviderProtocol?.keychainConfigData() else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in \(#function) guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        guard let storedConfig = tunnelProviderProtocol?.storedWireguardConfigurationFromData(keychainConfigData) else {
            wg_log(.info, message: "Parsable wireguard config not found in keychain, attempting to parse old format")
            // We've been started in the background. None of the new properties for server
            // status refresh will be available.

            guard let tunnelConfig = tunnelProviderProtocol?.tunnelConfigFromOldData(keychainConfigData, called: nil) else {
                errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                wg_log(.info, message: "Error in \(#function) guard 2: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
                return
            }

            wg_log(.info, message: "Starting tunnel with old configuration format.")
            startTunnelWithConfiguration(
                tunnelConfig,
                errorNotifier: errorNotifier,
                newVpnCertificateFeatures: nil,
                transport: transport,
                completionHandler: completionHandler
            )
            return
        }

        currentWireguardServer = storedConfig

        connectedLogicalId = tunnelProviderProtocol?.connectedLogicalId
        connectedIpId = tunnelProviderProtocol?.connectedServerIpId
        setLocalFeatureFlagOverrides(tunnelProviderProtocol?.featureFlagOverrides)
        ExtensionAPIService.forceEvictAnyPreviousSessionAssociatedKeysToAvoidConflictErrors = tunnelProviderProtocol?.unleashFeatureFlagShouldForceConflictRefresh ?? false

        startTunnelWithStoredConfig(errorNotifier: errorNotifier,
                                    newVpnCertificateFeatures: nil,
                                    completionHandler: completionHandler)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, staticMessage: "Stopping tunnel")
        #if CHECK_CONNECTIVITY
        self.stopTestingConnectivity()
        #endif

        certificateRefreshManager.stop { [unowned self] in
            self.serverStatusRefreshManager.stop {
                self.adapter.stop { error in
                    ErrorNotifier.removeLastErrorFile()

                    if let error = error {
                        wg_log(.error, message: "Failed to stop WireGuard adapter: \(error.localizedDescription)")
                    }
                    self.flushLogsToFile()
                    completionHandler()
                }
            }
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        do {
            let message = try WireguardProviderRequest.decode(data: messageData)
            handleProviderMessage(message) { response in
                completionHandler?(response.asData)
            }
        } catch {
            wg_log(.info, message: "App message decode error: \(error)")
            let response = WireguardProviderRequest.Response.error(message: "Unknown provider message.")
            completionHandler?(response.asData)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func handleProviderMessage(_ message: WireguardProviderRequest,
                               completionHandler: ((WireguardProviderRequest.Response) -> Void)?) {
        switch message {
        case .getRuntimeTunnelConfiguration:
            wg_log(.info, message: "Handle message: getRuntimeTunnelConfiguration")
            adapter.getRuntimeConfiguration { settings in
                if let settings = settings, let data = settings.data(using: .utf8) {
                    completionHandler?(.ok(data: data))
                }
                completionHandler?(.error(message: "Could not retrieve tunnel configuration."))
            }
        case .flushLogsToFile:
            wg_log(.info, message: "Handle message: flushLogsToFile")
            flushLogsToFile()
        case let .setApiSelector(selector, sessionCookie):
            wg_log(.info, message: "Handle message: setApiSelector")
            certificateRefreshManager.newSession(withSelector: selector, sessionCookie: sessionCookie) { result in
                switch result {
                case .success:
                    completionHandler?(.ok(data: nil))
                case .failure(let error):
                    completionHandler?(.error(message: String(describing: error)))
                }
            }
        case .refreshCertificate(let features):
            wg_log(.info, message: "Handle message: refreshCertificate")
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
            wg_log(.info, message: "Handle message: cancelRefreshes")
            certificateRefreshManager.stop {
                completionHandler?(.ok(data: nil))
            }
        case .restartRefreshes:
            wg_log(.info, message: "Handle message: restartRefreshes")
            certificateRefreshManager.start {
                completionHandler?(.ok(data: nil))
            }
        case .getCurrentLogicalAndServerId:
            let response = "\(self.connectedLogicalId ?? "");\(self.connectedIpId ?? "")"
            wg_log(.info, message: "Handle message: getCurrentLogicalAndServerId (result: \(response))")
            completionHandler?(.ok(data: response.data(using: .utf8)))
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        log.info("sleep()")

        #if CHECK_CONNECTIVITY
        self.stopTestingConnectivity()
        #endif

        certificateRefreshManager.suspend {
            self.serverStatusRefreshManager.suspend {
                completionHandler()
            }
        }
    }

    override func wake() {
        log.info("wake()")

        #if CHECK_CONNECTIVITY
        self.startTestingConnectivity()
        #endif

        certificateRefreshManager.resume {
            if self.shouldStartServerRefreshOnWake {
                self.serverStatusRefreshManager.resume { }
            }
        }
    }

    // MARK: - Logs

    // LoggingSystem crashes if bootstrap is called more than once during process lifetime, so we have to remember it was already set up
    private static var loggingSetupIsDone = false

    private func setupLogging() {
        // Our logger
        if !Self.loggingSetupIsDone {
            Self.loggingSetupIsDone = true
            LoggingSystem.bootstrap { _ in
                return WGLogHandler(formatter: WGLogFormatter())
            }
        }
        // WG logger
        Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
    }
    
    private func flushLogsToFile() {
        wg_log(.info, message: "Build info: \(appInfo.debugInfoString)")
        guard let path = FileManager.logTextFileURL?.path else { return }
        if Logger.global?.writeLog(to: path) ?? false {
            wg_log(.info, message: "flushLogsToFile written to file \(path) ")
        } else {
            wg_log(.info, message: "flushLogsToFile error while writing to file \(path) ")
        }
    }

    // MARK: - Connection tests

#if CHECK_CONNECTIVITY
    // Enable this in build settings if you want to debug connectivitiy issues.
    // It will ping API as well as 3rd party ip check site to check if we have the internet and are still connected to the proper server.
    // Please make sure this is NEVER enabled on Release builds!

    private var connectivityTimer: Timer?
    private var lastConnectivityCheck: Date = Date()

    private func startTestingConnectivity() {
        DispatchQueue.main.async {
            self.connectivityTimer?.invalidate()
            self.connectivityTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.checkConnectivity), userInfo: nil, repeats: true)
        }
    }

    private func stopTestingConnectivity() {
        DispatchQueue.main.async {
            self.connectivityTimer?.invalidate()
            self.connectivityTimer = nil
        }
    }

    @objc private func checkConnectivity() {
        let timeDiff = -lastConnectivityCheck.timeIntervalSinceNow
        if timeDiff > 60 * 3 {
            log.error("Seems like phone was sleeping! Last connectivity check time diff: \(timeDiff)")
        } else {
            log.info("Last connectivity check time diff: \(timeDiff)")
        }
        check(url: "https://api64.ipify.org/")
        lastConnectivityCheck = Date()
    }

    private func check(url urlString: String) {
        guard let url = URL(string: urlString), let host = url.host else {
            log.error("Can't get API endpoint hostname.", category: .api)
            return
        }
        let urlRequest = URLRequest(url: url)

        let task = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            let responseData = data != nil ? String(data: data!, encoding: .utf8) : "nil"
            log.debug("Host check finished", category: .net, metadata: ["host": "\(host)", "data": "\(String(describing: responseData))", "response": "\(String(describing: response))", "error": "\(String(describing: error))"])
        }
        task.resume()
    }

#endif
    
}

extension PacketTunnelProvider: ServerStatusRefreshDelegate {
    func reconnect(toAnyOf alternatives: [ServerStatusRequest.Logical]) {
        guard let newServer = alternatives.randomElement() else {
            log.error("Was told to reconnect, but alternatives were empty", category: .connection)
            return
        }
        self.restartTunnel(with: newServer)
    }
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}

// This lets us not depend on LocalFeatureFlags in VPNShared library
extension VPNShared.VpnReconnectionFeatureFlag: FeatureFlag { }
