// The Swift Programming Language
// https://docs.swift.org/swift-book

import NetworkExtension
import WireGuardKit
import WireGuardLogging

import Dependencies
import enum ExtensionIPC.WireguardProviderRequest
import VPNShared // vpnAuthenticationStorage Dependency
import NEHelper
import Timer
import Domain
import ConnectionFoundations

open class WireGuardPacketTunnelProvider: NEPacketTunnelProvider, ExtensionAPIServiceDelegate {
    public var dataTaskFactory: DataTaskFactory!

    private let timerFactory: TimerFactory
    private let appInfo: AppInfo
    private let certificateRefreshManager: ExtensionCertificateRefreshManager
    private let vpnAuthenticationStorage: VpnAuthenticationStorageSync

    private var currentWireguardServer: StoredWireguardConfig?
    // Currently connected logical server id
    private var connectedLogicalId: String?
    // Currently connected server ip id
    private var connectedIpId: String?

    var tunnelProviderProtocol: NETunnelProviderProtocol? {
        self.protocolConfiguration as? NETunnelProviderProtocol
    }

    public var transport: WireGuardTransport? {
        tunnelProviderProtocol?.wgProtocol.map(WireGuardTransport.init(rawValue:)) ?? .udp
    }

    public override init() {
        AppContext.default = .wireGuardExtension
        self.vpnAuthenticationStorage = VpnAuthenticationKeychain()
        self.appInfo = AppInfoImplementation(context: .wireGuardExtension)
        
        self.timerFactory = TimerFactoryImplementation()

        let keychainHandle = AuthKeychain.default
        let atlasSecret = Bundle.main.infoDictionary?["ProtonVPNAtlasSecret"] as? String ?? ""

        let apiService = ExtensionAPIService(
            timerFactory: timerFactory,
            keychain: keychainHandle,
            appInfo: self.appInfo,
            atlasSecret: atlasSecret
        )

        self.certificateRefreshManager = ExtensionCertificateRefreshManager(
            apiService: apiService,
            timerFactory: timerFactory,
            vpnAuthenticationStorage: self.vpnAuthenticationStorage,
            keychain: keychainHandle
        )
        
        super.init()

        self.dataTaskFactory = ConnectionTunnelDataTaskFactory(provider: self, timerFactory: timerFactory)
        apiService.delegate = self
        setupLogging()
    }

    deinit {
        wg_log(.info, message: "PacketTunnelProvider deinited")
    }

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(.info, message: message)
        }
    }()

    open override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "30 minutes"
        #endif

        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly" : "app"))
        flushLogsToFile() // Prevents empty logs in the app during the first WG connection

        guard let keychainConfigData = tunnelProviderProtocol?.keychainConfigData() else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.error, message: "Error in \(#function) guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        if let storedConfig = tunnelProviderProtocol?.storedWireguardConfigurationFromData(keychainConfigData) {
            currentWireguardServer = storedConfig

            connectedLogicalId = tunnelProviderProtocol?.connectedLogicalId
            connectedIpId = tunnelProviderProtocol?.connectedServerIpId
            ExtensionAPIService.forceEvictAnyPreviousSessionAssociatedKeysToAvoidConflictErrors = tunnelProviderProtocol?.unleashFeatureFlagShouldForceConflictRefresh ?? false

            startTunnelWithStoredConfig(
                errorNotifier: errorNotifier,
                newVpnCertificateFeatures: nil,
                completionHandler: completionHandler
            )
            return
        }

        wg_log(.info, message: "Parsable wireguard config not found in keychain, attempting to parse old format")
        // We've been started in the background. None of the new properties for server
        // status refresh will be available.

        if let tunnelConfig = tunnelProviderProtocol?.tunnelConfigFromOldData(keychainConfigData, called: nil) {
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

        errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
        completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
        wg_log(.error, message: "Error in \(#function): \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
    }

    /// Actually start a tunnel
    /// - Parameter newVpnCertificateFeatures: If not nil, will generate new certificate after connecting to the server and before starting certificate
    /// refresh manager. On new connection nil should be used not to regenerate current certificate.
    private func startTunnelWithStoredConfig(
        errorNotifier: ErrorNotifier,
        newVpnCertificateFeatures: VPNConnectionFeatures?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let errorHandler: ((PacketTunnelProviderError) -> Void) = { error in
            errorNotifier.notify(error)
            completionHandler(error)
        }

        guard let storedConfig = currentWireguardServer else {
            wg_log(.error, message: "Current wireguard server not set; not starting tunnel")
            errorHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.error, message: "Error in \(#function) guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        guard let transport else {
            wg_log(.error, message: "Error in \(#function) guard 2: missing socket type")
            errorHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: storedConfig.asWireguardConfiguration()) else {
            errorHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.error, message: "Error in \(#function) guard 3: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
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
        completionHandler: @escaping (Error?) -> Void
    ) {
        let errorHandler: ((PacketTunnelProviderError) -> Void) = { error in
            errorNotifier.notify(error)
            completionHandler(error)
        }

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
                errorHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
                errorHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(errorCode)")
                errorHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                wg_log(.error, message: "Starting tunnel failed with invalidState")
                errorHandler(PacketTunnelProviderError.adapterHasInvalidState)
            }
        }
    }

    private func connectionEstablished(newVpnCertificateFeatures: VPNConnectionFeatures?) {
        if let newVpnCertificateFeatures = newVpnCertificateFeatures {
            wg_log(.debug, message: "Connection restarted with another server. Will regenerate certificate.")

            certificateRefreshManager.checkRefreshCertificateNow(features: newVpnCertificateFeatures, userInitiated: true) { [weak self] result in
                wg_log(.info, message: "New certificate (after reconnection) result: \(result)")
                self?.certificateRefreshManager.start {
                    wg_log(.info, message: "CertificateRefreshManager successfully started")
                }
            }
        } else { // New connection
            certificateRefreshManager.start {
                wg_log(.info, message: "CertificateRefreshManager successfully started")
            }
        }

        #if CHECK_CONNECTIVITY
        self.startTestingConnectivity()
        #endif
    }

    open override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, message: "Stopping tunnel with reason: \(reason)")

        completionHandler()
    }

    open override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        do {
            let message = try WireguardProviderRequest.decode(data: messageData)

            handleProviderMessage(message) { response in
                completionHandler?(response.asData)
            }
        } catch {
            wg_log(.error, message: "Failed to decode app message")
            completionHandler?(nil)
        }
    }

    open override func sleep(completionHandler: @escaping () -> Void) {
        wg_log(.info, message: "Getting ready to sleep, stopping certificate manager...")

        certificateRefreshManager.stop {
            wg_log(.info, message: "Certificate manager stopped, proceeding with sleep")
            completionHandler()
        }
    }

    open override func wake() {
        wg_log(.info, message: "Waking up, starting certificate refresh manager...")

        certificateRefreshManager.start {
            wg_log(.info, message: "Certificate manager started, processing with waking up")
        }
    }
}

private extension WireGuardPacketTunnelProvider {
    private func flushLogsToFile() {
        wg_log(.info, message: "Build info: \(appInfo.debugInfoString)")
        guard let path = FileManager.logTextFileURL?.path else {
            wg_log(.error, message: "Cannot flush logs to file, file path is missing")
            return
        }
        if Logger.global?.writeLog(to: path) ?? false {
            wg_log(.info, message: "flushLogsToFile written to file \(path) ")
        } else {
            wg_log(.error, message: "flushLogsToFile error while writing to file \(path) ")
        }
    }

    func setupLogging() {
        Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
    }
}

private extension WireGuardPacketTunnelProvider {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func handleProviderMessage(
        _ message: WireguardProviderRequest,
        completionHandler: ((WireguardProviderRequest.Response) -> Void)?
    ) {
        wg_log(.info, message: "Handle message: \(message)")

        switch message {
        case .getRuntimeTunnelConfiguration:
            adapter.getRuntimeConfiguration { settings in
                if let settings = settings, let data = settings.data(using: .utf8) {
                    completionHandler?(.ok(data: data))
                } else {
                    completionHandler?(.error(message: "Could not retrieve tunnel configuration."))
                }
            }
        case .flushLogsToFile:
            flushLogsToFile()
        case let .setApiSelector(selector, sessionCookie):
            certificateRefreshManager.newSession(withSelector: selector, sessionCookie: sessionCookie) { result in
                switch result {
                case .success:
                    completionHandler?(.ok(data: nil))
                case .failure(let error):
                    completionHandler?(.error(message: String(describing: error)))
                }
            }
        case .refreshCertificate(let features):
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
            certificateRefreshManager.stop {
                completionHandler?(.ok(data: nil))
            }
        case .restartRefreshes:
            certificateRefreshManager.start {
                completionHandler?(.ok(data: nil))
            }
        case .getCurrentLogicalAndServerId:
            let response = "\(self.connectedLogicalId ?? "");\(self.connectedIpId ?? "")"
            wg_log(.info, message: "Result: \(response))")
            completionHandler?(.ok(data: response.data(using: .utf8)))
        }
    }
}
