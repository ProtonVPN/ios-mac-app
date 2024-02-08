//
//  VpnManager.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import NetworkExtension

import Dependencies

import Domain
import Ergonomics
import LocalFeatureFlags
import ExtensionIPC
import VPNShared

import Home

public protocol VpnManagerProtocol {

    var stateChanged: (() -> Void)? { get set }
    var state: VpnState { get }
    var localAgentStateChanged: ((Bool?) -> Void)? { get set }
    var isLocalAgentConnected: Bool? { get }
    var currentVpnProtocol: VpnProtocol? { get }

    var netShieldStats: NetShieldModel { get }

    func appBackgroundStateDidChange(isBackground: Bool)
    func isOnDemandEnabled(handler: @escaping (Bool) -> Void)
    func setOnDemand(_ enabled: Bool)
    func disconnectAnyExistingConnectionAndPrepareToConnect(with configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func connectedDate() async -> Date?
    func refreshState()
    func refreshManagers()
    func removeConfigurations(completionHandler: ((Error?) -> Void)?)

    /// Called when `VpnManager` is ready and has finished querying the device's VPN connection state.
    /// - Note: Only call this function once over the course of `VpnManager`'s lifetime.
    func whenReady(queue: DispatchQueue, completion: @escaping () -> Void)

    func set(vpnAccelerator: Bool)
    func set(netShieldType: NetShieldType)
    func set(natType: NATType)
    func set(safeMode: Bool)
}

public protocol VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol
}

public class VpnManager: VpnManagerProtocol {
    @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

    private var quickReconnection = false
    
    internal let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)
    
    private let ikeProtocolFactory: VpnProtocolFactory
    private let openVpnProtocolFactory: VpnProtocolFactory
    private let wireguardProtocolFactory: VpnProtocolFactory

    internal let localAgentConnectionFactory: LocalAgentConnectionFactory
    
    private let vpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory

    public internal (set) var netShieldStats: NetShieldModel = .init(trackers: 0, ads: 0, data: 0, enabled: false)

    // hacky way to initiase DependencyValues before we enter LocalAgentQueue to avoid deadlock during tests
    @Dependency(\.timerFactory) var timerFactory
    
    var currentVpnProtocolFactory: VpnProtocolFactory? {
        guard let currentVpnProtocol = currentVpnProtocol else {
            return nil
        }
        
        switch currentVpnProtocol {
        case .ike:
            return ikeProtocolFactory
        case .openVpn:
            return openVpnProtocolFactory
        case .wireGuard:
            return wireguardProtocolFactory
        }
    }
    
    private var connectAllowed = true
    internal var disconnectOnCertRefreshError = true
    private var disconnectCompletion: (() -> Void)?
    
    // Holds a request for connection/disconnection etc for after the VPN frameworks are loaded
    private var delayedDisconnectRequest: (() -> Void)?
    private var hasConnected: Bool {
        switch currentVpnProtocol {
        case .ike:
            return propertiesManager.hasConnected
        default:
            return true
        }
    }

    public private(set) var state: VpnState = .invalid
    public var readyGroup: DispatchGroup? = DispatchGroup()

    public var currentVpnProtocol: VpnProtocol? {
        didSet {
            if oldValue == nil, let delayedRequest = delayedDisconnectRequest {
                delayedRequest()
                delayedDisconnectRequest = nil
            }
        }
    }
    public var stateChanged: (() -> Void)?

    private let localAgentIsConnectedQueue = DispatchQueue(label: "ch.protonvpn.local-agent.is-connected")
    private var _isLocalAgentConnectedNoSync: Bool?
    public internal(set) var isLocalAgentConnected: Bool? {
        get {
            return localAgentIsConnectedQueue.sync {
                _isLocalAgentConnectedNoSync
            }
        }
        set {
            var oldValue: Bool?
            localAgentIsConnectedQueue.sync {
                oldValue = _isLocalAgentConnectedNoSync
                _isLocalAgentConnectedNoSync = newValue
            }

            guard isLocalAgentConnected != oldValue else {
                return
            }
            localAgentStateChanged?(isLocalAgentConnected)
        }
    }
    public var localAgentStateChanged: ((Bool?) -> Void)?
    
    /// App group is used to read errors from OpenVPN in user defaults
    private let appGroup: String

    private let vpnStateConfiguration: VpnStateConfiguration

    var natTypePropertyProvider: NATTypePropertyProvider
    var netShieldPropertyProvider: NetShieldPropertyProvider
    var safeModePropertyProvider: SafeModePropertyProvider

    let propertiesManager: PropertiesManagerProtocol
    let alertService: CoreAlertService?
    let vpnAuthentication: VpnAuthentication
    let vpnKeychain: VpnKeychainProtocol
    let vpnAuthenticationStorage: VpnAuthenticationStorageSync

    var localAgent: LocalAgent? {
        didSet {
            if localAgent == nil {
                isLocalAgentConnected = nil
            }
        }
    }
    let serverStorage: ServerStorage // Used to find new server/ip in case NE had to reconnect to another server

    var notificationCenter: NotificationCenter = .default
    private var tokens: [UUID: NotificationToken] = [:]

    public typealias Factory = IkeProtocolFactoryCreator
        & OpenVpnProtocolFactoryCreator
        & WireguardProtocolFactoryCreator
        & VpnAuthenticationFactory
        & VpnAuthenticationStorageFactory
        & VpnKeychainFactory
        & PropertiesManagerFactory
        & VpnStateConfigurationFactory
        & CoreAlertServiceFactory
        & VpnCredentialsConfiguratorFactoryCreator
        & LocalAgentConnectionFactoryCreator
        & NATTypePropertyProviderFactory
        & NetShieldPropertyProviderFactory
        & SafeModePropertyProviderFactory
        & ServerStorageFactory

    public convenience init(_ factory: Factory, config: Container.Config) {
        self.init(
            ikeFactory: factory.makeIkeProtocolFactory(),
            openVpnFactory: factory.makeOpenVpnProtocolFactory(),
            wireguardProtocolFactory: factory.makeWireguardProtocolFactory(),
            appGroup: config.appGroup,
            vpnAuthentication: factory.makeVpnAuthentication(),
            vpnAuthenticationStorage: factory.makeVpnAuthenticationStorage(),
            vpnKeychain: factory.makeVpnKeychain(),
            propertiesManager: factory.makePropertiesManager(),
            vpnStateConfiguration: factory.makeVpnStateConfiguration(),
            alertService: factory.makeCoreAlertService(),
            vpnCredentialsConfiguratorFactory: factory.makeVpnCredentialsConfiguratorFactory(),
            localAgentConnectionFactory: factory.makeLocalAgentConnectionFactory(),
            natTypePropertyProvider: factory.makeNATTypePropertyProvider(),
            netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(),
            safeModePropertyProvider: factory.makeSafeModePropertyProvider(),
            serverStorage: factory.makeServerStorage()
        )
    }
    
    public init(
        ikeFactory: VpnProtocolFactory,
        openVpnFactory: VpnProtocolFactory,
        wireguardProtocolFactory: VpnProtocolFactory,
        appGroup: String,
        vpnAuthentication: VpnAuthentication,
        vpnAuthenticationStorage: VpnAuthenticationStorageSync,
        vpnKeychain: VpnKeychainProtocol,
        propertiesManager: PropertiesManagerProtocol,
        vpnStateConfiguration: VpnStateConfiguration,
        alertService: CoreAlertService? = nil,
        vpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory,
        localAgentConnectionFactory: LocalAgentConnectionFactory,
        natTypePropertyProvider: NATTypePropertyProvider,
        netShieldPropertyProvider: NetShieldPropertyProvider,
        safeModePropertyProvider: SafeModePropertyProvider,
        serverStorage: ServerStorage
    ) {
        readyGroup?.enter()

        self.ikeProtocolFactory = ikeFactory
        self.openVpnProtocolFactory = openVpnFactory
        self.wireguardProtocolFactory = wireguardProtocolFactory
        self.appGroup = appGroup
        self.alertService = alertService
        self.vpnAuthentication = vpnAuthentication
        self.vpnAuthenticationStorage = vpnAuthenticationStorage
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.vpnStateConfiguration = vpnStateConfiguration
        self.vpnCredentialsConfiguratorFactory = vpnCredentialsConfiguratorFactory
        self.localAgentConnectionFactory = localAgentConnectionFactory
        self.natTypePropertyProvider = natTypePropertyProvider
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.serverStorage = serverStorage
        
        prepareManagers(forSetup: true)
    }

    // App was moved to/from the background mode (iOS only)
    public func appBackgroundStateDidChange(isBackground: Bool) {
        connectionQueue.sync { [weak self] in
            self?.disconnectOnCertRefreshError = !isBackground
            if !isBackground {
                self?.checkActiveServer()
            }
        }
    }
    
    public func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            handler(false)
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .status) { vpnManager, _ in
            guard let vpnManager = vpnManager else {
                handler(false)
                return
            }
            
            handler(vpnManager.isOnDemandEnabled)
        }
    }
    
    public func setOnDemand(_ enabled: Bool) {
        connectionQueue.async { [weak self] in
            self?.setOnDemand(enabled) { _ in }
        }
    }
    
    public func disconnectAnyExistingConnectionAndPrepareToConnect(with configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        let pause = state != .disconnected ? 0.2 : 0 // Magical fix for strange crash of go mobile and/or LocagAgent lib + KS
        disconnect { [weak self] in
            self?.currentVpnProtocol = configuration.vpnProtocol
            log.info("About to start connection process", category: .connectionConnect)
            self?.connectAllowed = true
            self?.connectionQueue.asyncAfter(deadline: .now() + pause) { [weak self] in
                self?.prepareConnection(forConfiguration: configuration, completion: completion)
            }
        }
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        executeDisconnectionRequestWhenReady { [weak self] in
            self?.connectAllowed = false
            self?.connectionQueue.async { [weak self] in
                guard let self = self else {
                    return
                }

                self.startDisconnect(completion: completion)
            }
        }
    }
    
    public func removeConfigurations(completionHandler: ((Error?) -> Void)? = nil) {
        let dispatchGroup = DispatchGroup()
        var error: Error?
        var successful = false // mark as success if at least one removal succeeded

        for factory in [ikeProtocolFactory, openVpnProtocolFactory, wireguardProtocolFactory] {
            dispatchGroup.enter()
            removeConfiguration(factory) { e in
                if e != nil {
                    error = e
                } else {
                    successful = true
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            completionHandler?(successful ? nil : error)
        }
    }

    @available(*, deprecated, renamed: "connectedDate()")
    private func connectedDate(completion: @escaping (Date?) -> Void) {
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            completion(nil)
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] vpnManager, error in
            guard let self = self else {
                completion(nil)
                return
            }

            if error != nil {
                completion(nil)
                return
            }

            guard let vpnManager = vpnManager else {
                completion(nil)
                return
            }
            
            // Returns a date if currently connected
            if case VpnState.connected(_) = self.state {
                completion(vpnManager.vpnConnection.connectedDate)
            } else {
                completion(nil)
            }
        }
    }

    public func connectedDate() async -> Date? {
        await withCheckedContinuation { continuation in
            connectedDate(completion: continuation.resume)
        }
    }
    
    public func refreshState() {
        setState()
    }
    
    public func refreshManagers() {
        // Stop recieving status updates until the manager is prepared
        notificationCenter.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        
        prepareManagers()
    }

    public func set(vpnAccelerator: Bool) {
        guard let localAgent = localAgent else {
            log.error("Trying to change vpn accelerator via local agent when local agent instance does not exist", category: .settings)
            return
        }

        localAgent.update(vpnAccelerator: vpnAccelerator)
    }

    public func set(netShieldType: NetShieldType) {
        guard let localAgent = localAgent else {
            log.error("Trying to change netshield via local agent when local agent instance does not exist", category: .settings)
            return
        }

        // also update the last connection request and active connection for retries and reconnections
        updateActiveConnection(netShieldType: netShieldType)
        localAgent.update(netshield: netShieldType)
    }

    public func set(natType: NATType) {
        guard let localAgent = localAgent else {
            log.error("Trying to change NAT type via local agent when local agent instance does not exist", category: .settings)
            return
        }

        // also update the last connection request and active connection for retries and reconnections
        updateActiveConnection(natType: natType)
        localAgent.update(natType: natType)
    }

    public func set(safeMode: Bool) {
        guard let localAgent = localAgent else {
            log.error("Trying to change Safe Mode via local agent when local agent instance does not exist", category: .settings)
            return
        }

        updateActiveConnection(safeMode: safeMode)
        localAgent.update(safeMode: safeMode)
    }
    
    // MARK: - Private functions

    // MARK: - Connecting
    private func prepareConnection(forConfiguration configuration: VpnManagerConfiguration,
                                   completion: @escaping () -> Void) {
        if state.volatileConnection {
            setState()
            return
        }

        disconnectLocalAgent()
        
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        log.info("Creating connection configuration", category: .connectionConnect)
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self = self else {
                return
            }

            if let error = error {
                self.setState(withError: error)
                return
            }

            guard let vpnManager = vpnManager else { return }

            do {
                let protocolConfiguration = try currentVpnProtocolFactory
                    .create(configuration)
                let credentialsConfigurator = self.vpnCredentialsConfiguratorFactory
                    .getCredentialsConfigurator(for: configuration.vpnProtocol)
                
                credentialsConfigurator.prepareCredentials(for: protocolConfiguration, configuration: configuration) { protocolConfigurationWithCreds in
                    self.configureConnection(forProtocol: protocolConfigurationWithCreds, vpnManager: vpnManager) {
                        self.startConnection(requestId: configuration.id, originalIntent: configuration.intent, completion: completion)
                    }
                }
                
            } catch {
                log.error("\(error)", category: .ui)
            }
        }
    }
    
    private func configureConnection(forProtocol configuration: NEVPNProtocol,
                                     vpnManager: NEVPNManagerWrapper,
                                     completion: @escaping () -> Void) {
        guard connectAllowed else {
            return            
        }
        
        log.info("Configuring connection", category: .connectionConnect)
        
        // MARK: - KillSwitch configuration
        if #available(iOS 14.2, *) {
            configuration.excludeLocalNetworks = featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
        }
        configuration.includeAllNetworks = propertiesManager.killSwitch
        
        if case .wireGuard(let type) = currentVpnProtocol, configuration is NETunnelProviderProtocol {
            (configuration as? NETunnelProviderProtocol)?.wgProtocol = type.rawValue
        }

        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        vpnManager.isOnDemandEnabled = hasConnected
        vpnManager.isEnabled = true
        
        let saveToPreferences = {
            vpnManager.saveToPreferences { [weak self] saveError in
                guard let self = self else {
                    return
                }

                if let saveError = saveError {
                    self.setState(withError: saveError)
                    return
                }
                
                completion()
            }
        }
        
        // Any non-personal VPN configuration with includeAllNetworks enabled, prevents IKEv2 (with includeAllNetworks) from connecting. #VPNAPPL-566
        if configuration.includeAllNetworks && configuration.isKind(of: NEVPNProtocolIKEv2.self) {
            self.removeConfiguration(self.openVpnProtocolFactory, completionHandler: { _ in
                self.removeConfiguration(self.wireguardProtocolFactory, completionHandler: { _ in
                    saveToPreferences()
                })
            })
        } else {
            saveToPreferences()
        }
                
    }
    
    private func startConnection(requestId: UUID, originalIntent: ConnectionRequestType?, completion: @escaping () -> Void) {
        guard connectAllowed, let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        log.info("Loading connection configuration", category: .connectionConnect)
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self = self else {
                return
            }

            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            guard self.connectAllowed else { return }
            do {
                log.info("Starting VPN tunnel", category: .connectionConnect)

                // If we have the original intent, add a notification listener which will wait for the connection
                // status to change before removing itself. This listener is keyed off of the connection request id, so
                // it should be unique to a given connection request. A better way to do this would be to save the UUID
                // on the actual `NEVPNConnection` object, but only `NETunnelProviderProtocol`s have dictionaries that
                // we can save arbitrary data to. If the notification handler's function is called, it is *not
                // guaranteed* that it was as a result of the connection request with the `requestId` UUID.
                if let originalIntent {
                    tokens[requestId] = notificationCenter.addObserver(
                        for: .NEVPNStatusDidChange,
                        object: nil,
                        handler: { [weak self] notification in
                            guard let connection = notification.object as? NEVPNConnectionWrapper,
                                  connection.status != .connecting else {
                                return
                            }

                            defer {
                                self?.tokens.removeValue(forKey: requestId)
                            }

                            guard connection.status == .connected, let date = connection.connectedDate else {
                                return
                            }
                            if originalIntent == .random {
                                @Dependency(\.serverChangeAuthorizer) var serverChangeAuthorizer
                                serverChangeAuthorizer.registerServerChange(connectedAt: date)
                            }
                        }
                    )
                }

                try vpnManager.vpnConnection.startVPNTunnel()
                completion()
            } catch {
                self.setState(withError: error)
            }
        }
    }
    
    // MARK: - Disconnecting
    private func startDisconnect(completion: @escaping (() -> Void)) {
        log.info("Closing VPN tunnel", category: .connectionDisconnect)

        localAgent?.disconnect()
        disconnectCompletion = completion
        
        setOnDemand(false) { vpnManager in
            self.stopTunnelOrRunCompletion(vpnManager: vpnManager)
        }
    }
    
    private func stopTunnelOrRunCompletion(vpnManager: NEVPNManagerWrapper) {
        switch self.state {
        case .disconnected, .error, .invalid:
            disconnectCompletion?() // ensures the completion handler is run already disconnected
            disconnectCompletion = nil
        default:
            vpnManager.vpnConnection.stopVPNTunnel()
        }
    }
    
    // MARK: - Connect on demand
    private func setOnDemand(_ enabled: Bool, completion: @escaping (NEVPNManagerWrapper) -> Void) {
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self = self else {
                return
            }

            if let error = error {
                self.setState(withError: error)
                return
            }

            guard let vpnManager = vpnManager else {
                self.setState(withError: ProtonVpnError.vpnManagerUnavailable)
                return
            }
            
            vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
            vpnManager.isOnDemandEnabled = enabled
            log.info("On Demand set: \(enabled ? "On" : "Off") for \(currentVpnProtocolFactory.self)", category: .connectionConnect)
            
            vpnManager.saveToPreferences { [weak self] error in
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.setState(withError: error)
                    return
                }
                
                completion(vpnManager)
            }
        }
    }
    
    private func setState(withError error: Error? = nil) {
        if let error = error {
            log.error("VPN error: \(error)", category: .connection)
            state = .error(error)
            disconnectCompletion?()
            disconnectCompletion = nil
            self.stateChanged?()
            return
        }

        guard let vpnProtocol = currentVpnProtocol else {
            return
        }

        vpnStateConfiguration.determineActiveVpnState(vpnProtocol: vpnProtocol) { [weak self] result in
            guard let self = self, !self.quickReconnection else {
                return
            }

            switch result {
            case let .failure(error):
                self.setState(withError: error)
            case let .success((vpnManager, newState)):
                guard newState != self.state else {
                    return
                }

                switch newState {
                case .disconnecting:
                    self.quickReconnection = true
                    self.connectionQueue.asyncAfter(deadline: .now() + CoreAppConstants.UpdateTime.quickReconnectTime) {
                        let newState = self.vpnStateConfiguration.determineNewState(vpnManager: vpnManager)
                        switch newState {
                        case .connecting:
                            self.connectionQueue.asyncAfter(deadline: .now() + CoreAppConstants.UpdateTime.quickUpdateTime) {
                                self.updateState(vpnManager)
                            }
                        default:
                            self.updateState(vpnManager)
                        }
                    }
                default:
                    self.updateState(vpnManager)
                }
            }
        }
    }
    
    private func updateState(_ vpnManager: NEVPNManagerWrapper) {
        quickReconnection = false
        let newState = vpnStateConfiguration.determineNewState(vpnManager: vpnManager)
        guard newState != self.state else { return }
        self.state = newState
        log.info("VPN update state to \(self.state.logDescription)", category: .connection, event: .change)
        
        switch self.state {
        case .connecting:
            if !self.connectAllowed {
                log.info("VPN connection not allowed, will disconnect now.", category: .connection)
                self.disconnect {}
                return // prevent UI from updating with the connecting state
            }
            
            if let currentVpnProtocol = self.currentVpnProtocol, case VpnProtocol.ike = currentVpnProtocol, !self.propertiesManager.hasConnected {
                self.propertiesManager.hasConnected = true
            }
        case .error(let error):
            if case ProtonVpnError.tlsServerVerification = error {
                self.disconnect {}
                SentryHelper.shared?.log(error: error)
                self.alertService?.push(alert: MITMAlert(messageType: .vpn))
                break
            }
            if case ProtonVpnError.tlsInitialisation = error {
                self.disconnect {} // Prevent infinite connection loop
                break
            }
            fallthrough
        case .disconnected, .invalid:
            self.disconnectCompletion?()
            self.disconnectCompletion = nil
            setRemoteAuthenticationEndpoint(provider: nil)
            disconnectLocalAgent()
        case .connected:
            setRemoteAuthenticationEndpoint(provider: vpnManager.vpnConnection as? ProviderMessageSender)
            self.connectLocalAgent()
        default:
            break
        }

        self.stateChanged?()
    }

    /// Point our `VpnAuthentication` instance to the NE provider, so that we can communicate with the extension to
    /// fetch certificates.
    ///
    /// - note: This does nothing on MacOS, since we rely on the host app to manage certificates.
    private func setRemoteAuthenticationEndpoint(provider: ProviderMessageSender?) {
        #if os(iOS)
        guard let remoteVpnAuthentication = vpnAuthentication as? VpnAuthenticationRemoteClient else {
            log.error("Failed to set connection provider", category: .connection, metadata: ["authenticationManagerType": "\(type(of: vpnAuthentication))"])
            return
        }
        remoteVpnAuthentication.setConnectionProvider(provider: provider)
        #endif
    }

    /*
     *  Upon initiation of VPN manager, VPN configuration from manager needs
     *  to be loaded in order for storing of further configurations to work.
     */
    private func prepareManagers(forSetup: Bool = false) {
        vpnStateConfiguration.determineActiveVpnProtocol(defaultToIke: true) { [weak self] vpnProtocol in
            guard let self = self else {
                return
            }

            self.currentVpnProtocol = vpnProtocol
            self.setState()

            notificationCenter.removeObserver(
                self,
                name: NSNotification.Name.NEVPNStatusDidChange,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(self.vpnStatusChanged),
                name: NSNotification.Name.NEVPNStatusDidChange,
                object: nil
            )

            if forSetup {
                self.readyGroup?.leave()
            }
        }
    }

    public func whenReady(queue: DispatchQueue, completion: @escaping () -> Void) {
        self.readyGroup?.notify(queue: queue) {
            completion()
            self.readyGroup = nil
        }
    }
    
    @objc private func vpnStatusChanged() {
        setState()
    }
    
    private func removeConfiguration(_ protocolFactory: VpnProtocolFactory, completionHandler: ((Error?) -> Void)?) {
        protocolFactory.vpnProviderManager(for: .configuration) { vpnManager, error in
            if let error = error {
                log.error("\(error)", category: .ui)
                completionHandler?(ProtonVpnError.removeVpnProfileFailed)
                return
            }
            guard let vpnManager = vpnManager else {
                completionHandler?(ProtonVpnError.removeVpnProfileFailed)
                return
            }
            
            vpnManager.protocolConfiguration = nil
            vpnManager.removeFromPreferences(completionHandler: completionHandler)
        }
    }
    
    private func executeDisconnectionRequestWhenReady(request: @escaping () -> Void) {
        if currentVpnProtocol == nil {
            delayedDisconnectRequest = request
        } else {
            request()
        }
    }    
}
