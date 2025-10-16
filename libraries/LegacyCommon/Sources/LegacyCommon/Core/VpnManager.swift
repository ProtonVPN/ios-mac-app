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

import ComposableArchitecture
import Dependencies

import ProtonCoreFeatureFlags

import Domain
import Ergonomics
import ExtensionIPC
import ExtensionManager
import NetShield
import VPNAppCore
import VPNShared

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
    func refreshManagers() async
    func removeConfigurations(completionHandler: ((Error?) -> Void)?)

    /// Task used to track when the managers are ready. Retrieve the value of the task to be sure
    /// the `VpnManager` is ready and has finished querying the device's VPN connection state.
    var prepareManagersTask: Task<Void, Never>? { get }

    func set(vpnAccelerator: Bool)
    func set(netShieldType: NetShieldType)
    func set(natType: NATType)
    func set(safeMode: Bool)
    func set(portForwarding: Bool)

    #if os(macOS)
        func startNATPortMappingService()
        func stopNATPortMappingService()
    #endif
}

public protocol VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol
}

public final class VpnManager: VpnManagerProtocol {
    @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

    private var quickReconnection = false

    let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)

    private let ikeProtocolFactory: VpnProtocolFactory
    private let wireguardProtocolFactory: VpnProtocolFactory

    let localAgentConnectionFactory: LocalAgentConnectionFactory

    private let vpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory

    public internal(set) var netShieldStats: NetShieldModel = .zero(enabled: false)

    // hacky way to initiase DependencyValues before we enter LocalAgentQueue to avoid deadlock during tests
    @Dependency(\.timerFactory) var timerFactory

    #if os(macOS)
        private var plutoniumUpdateTask: Task<Void, Never>?
    #endif

    var currentVpnProtocolFactory: VpnProtocolFactory? {
        guard let currentVpnProtocol else {
            return nil
        }

        switch currentVpnProtocol {
        case .ike:
            return ikeProtocolFactory
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case .wireGuard:
            return wireguardProtocolFactory
        }
    }

    private var connectAllowed = true
    var disconnectOnCertRefreshError = true
    private var disconnectCompletion: (() -> Void)?

    // Holds a request for connection/disconnection etc for after the VPN frameworks are loaded
    private var delayedDisconnectRequest: (() -> Void)?
    private var hasConnected: Bool {
        switch currentVpnProtocol {
        case .ike:
            propertiesManager.hasConnected
        default:
            true
        }
    }

    public private(set) var state: VpnState = .invalid

    public var prepareManagersTask: Task<Void, Never>?

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
            localAgentIsConnectedQueue.sync {
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

    @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
    var netShieldPropertyProvider: NetShieldPropertyProvider
    var safeModePropertyProvider: SafeModePropertyProvider
    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider

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

    var notificationCenter: NotificationCenter = .default
    private var tokens: [UUID: NotificationToken] = [:]

    public typealias Factory = CoreAlertServiceFactory
        & IkeProtocolFactoryCreator
        & LocalAgentConnectionFactoryCreator
        & NetShieldPropertyProviderFactory
        & PropertiesManagerFactory
        & SafeModePropertyProviderFactory
        & VpnAuthenticationFactory
        & VpnAuthenticationStorageFactory
        & VpnCredentialsConfiguratorFactoryCreator
        & VpnKeychainFactory
        & VpnStateConfigurationFactory
        & WireguardProtocolFactoryCreator

    public convenience init(_ factory: Factory, config: Container.Config) {
        self.init(
            ikeFactory: factory.makeIkeProtocolFactory(),
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
            netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(),
            safeModePropertyProvider: factory.makeSafeModePropertyProvider()
        )
    }

    public init(
        ikeFactory: VpnProtocolFactory,
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
        netShieldPropertyProvider: NetShieldPropertyProvider,
        safeModePropertyProvider: SafeModePropertyProvider
    ) {
        self.ikeProtocolFactory = ikeFactory
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
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider

        self.prepareManagersTask = Task {
            await prepareManagers()
        }
    }

    // App was moved to/from the background mode (iOS only)
    public func appBackgroundStateDidChange(isBackground: Bool) {
        connectionQueue.sync { [weak self] in
            self?.disconnectOnCertRefreshError = !isBackground
        }
    }

    public func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        guard let currentVpnProtocolFactory else {
            handler(false)
            return
        }

        currentVpnProtocolFactory.vpnProviderManager(for: .status) { vpnManager, _ in
            guard let vpnManager else {
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
                guard let self else {
                    return
                }

                startDisconnect(completion: completion)
            }
        }
    }

    public func removeConfigurations(completionHandler: ((Error?) -> Void)? = nil) {
        let dispatchGroup = DispatchGroup()
        var error: Error?
        var successful = false // mark as success if at least one removal succeeded

        for factory in [ikeProtocolFactory, wireguardProtocolFactory] {
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
        guard let currentVpnProtocolFactory else {
            completion(nil)
            return
        }

        currentVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] vpnManager, error in
            guard let self else {
                completion(nil)
                return
            }

            if error != nil {
                completion(nil)
                return
            }

            guard let vpnManager else {
                completion(nil)
                return
            }

            // Returns a date if currently connected
            if case VpnState.connected = state {
                completion(vpnManager.vpnConnection.connectedDate)
            } else {
                completion(nil)
            }
        }
    }

    public func connectedDate() async -> Date? {
        guard let currentVpnProtocolFactory else {
            return nil
        }
        do {
            let vpnManager = try await currentVpnProtocolFactory.vpnProviderManager(for: .status)
            // Returns a date if currently connected
            if case VpnState.connected = state {
                return vpnManager.vpnConnection.connectedDate
            }
        } catch {
            log.debug("Couldn't retrieve vpnProviderManager \(error)", category: .connection)
        }
        return nil
    }

    public func refreshState() {
        setState()
    }

    public func refreshManagers() {
        // Stop recieving status updates until the manager is prepared
        notificationCenter.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)

        prepareManagers()
    }

    public func refreshManagers() async {
        // Stop recieving status updates until the manager is prepared
        notificationCenter.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)

        await prepareManagers()
    }

    public func set(vpnAccelerator: Bool) {
        guard let localAgent else {
            log.error("Trying to change vpn accelerator via local agent when local agent instance does not exist", category: .settings)
            return
        }

        localAgent.update(vpnAccelerator: vpnAccelerator)
    }

    public func set(netShieldType: NetShieldType) {
        guard let localAgent else {
            log.error("Trying to change netshield via local agent when local agent instance does not exist", category: .settings)
            return
        }

        // also update the last connection request and active connection for retries and reconnections
        updateActiveConnection(netShieldType: netShieldType)
        localAgent.update(netshield: netShieldType)
    }

    public func set(natType: NATType) {
        guard let localAgent else {
            log.error("Trying to change NAT type via local agent when local agent instance does not exist", category: .settings)
            return
        }

        // also update the last connection request and active connection for retries and reconnections
        updateActiveConnection(natType: natType)
        localAgent.update(natType: natType)
    }

    public func set(safeMode: Bool) {
        guard let localAgent else {
            log.error("Trying to change Safe Mode via local agent when local agent instance does not exist", category: .settings)
            return
        }

        updateActiveConnection(safeMode: safeMode)
        localAgent.update(safeMode: safeMode)
    }

    public func set(portForwarding: Bool) {
        guard let localAgent else {
            log.error("Trying to change Port Forwarding via local agent when local agent instance does not exist", category: .settings)
            return
        }

        updateActiveConnection(portForwarding: portForwarding)
        localAgent.update(portForwarding: portForwarding)
    }

    // MARK: - Private functions

    // MARK: - Connecting

    private func prepareConnection(
        forConfiguration configuration: VpnManagerConfiguration,
        completion: @escaping () -> Void
    ) {
        if state.volatileConnection {
            setState()
            return
        }

        disconnectLocalAgent()

        guard let currentVpnProtocolFactory else {
            return
        }

        log.info("Creating connection configuration", category: .connectionConnect)
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self else {
                return
            }

            if let error {
                setState(withError: error)
                return
            }

            guard let vpnManager else { return }

            do {
                let protocolConfiguration = try currentVpnProtocolFactory
                    .create(configuration)
                let credentialsConfigurator = vpnCredentialsConfiguratorFactory
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

    private func configureConnection(
        forProtocol configuration: NEVPNProtocol,
        vpnManager: NEVPNManagerWrapper,
        completion: @escaping () -> Void
    ) {
        guard connectAllowed else {
            return
        }

        log.info("Configuring connection", category: .connectionConnect)

        // MARK: - KillSwitch configuration

        if #available(iOS 14.2, *) {
            configuration.excludeLocalNetworks = featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
        }
        configuration.includeAllNetworks = propertiesManager.killSwitch

        if case let .wireGuard(type) = currentVpnProtocol, configuration is NETunnelProviderProtocol {
            (configuration as? NETunnelProviderProtocol)?.wgProtocol = type.rawValue
        }

        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        vpnManager.isOnDemandEnabled = hasConnected
        vpnManager.isEnabled = true

        let saveToPreferences = {
            vpnManager.saveToPreferences { [weak self] saveError in
                guard let self else {
                    return
                }

                if let saveError {
                    setState(withError: saveError)
                    return
                }

                completion()
            }
        }

        // Any non-personal VPN configuration with includeAllNetworks enabled, prevents IKEv2 (with includeAllNetworks) from connecting. #VPNAPPL-566
        if configuration.includeAllNetworks, configuration.isKind(of: NEVPNProtocolIKEv2.self) {
            removeConfiguration(wireguardProtocolFactory, completionHandler: { _ in
                saveToPreferences()
            })
        } else {
            saveToPreferences()
        }
    }

    private func startConnection(requestId: UUID, originalIntent: ConnectionRequestType?, completion: @escaping () -> Void) {
        guard connectAllowed, let currentVpnProtocolFactory else {
            return
        }

        log.info("Loading connection configuration", category: .connectionConnect)
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self else {
                return
            }

            if let error {
                setState(withError: error)
                return
            }
            guard let vpnManager else { return }
            guard connectAllowed else { return }

            tokens.removeAll()

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
                        object: vpnManager.vpnConnection, // subscribe only to events regarding the current connection
                        handler: { [weak self] notification in
                            guard let connection = notification.object as? NEVPNConnectionWrapper else {
                                log.assertionFailure("Connection object missing from notification", category: .connection)
                                return
                            }
                            log.debug("Server change observer received status", category: .connection, metadata: [
                                "requestId": "\(requestId)",
                                "connection": "\(connection)",
                                "status": "\(connection.status)",
                            ])
                            guard connection.status != .connecting else {
                                return
                            }

                            guard connection.status == .connected, let date = connection.connectedDate else {
                                return
                            }

                            defer {
                                self?.tokens.removeValue(forKey: requestId)
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
                setState(withError: error)
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
        switch state {
        case .disconnected, .error, .invalid:
            disconnectCompletion?() // ensures the completion handler is run already disconnected
            disconnectCompletion = nil
        default:
            vpnManager.vpnConnection.stopVPNTunnel()
        }
    }

    // MARK: - Connect on demand

    private func setOnDemand(_ enabled: Bool, completion: @escaping (NEVPNManagerWrapper) -> Void) {
        guard let currentVpnProtocolFactory else {
            return
        }

        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let self else {
                return
            }

            if let error {
                setState(withError: error)
                return
            }

            guard let vpnManager else {
                setState(withError: CommonVpnError.vpnManagerUnavailable)
                return
            }

            vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
            vpnManager.isOnDemandEnabled = enabled
            log.info("On Demand set: \(enabled ? "On" : "Off") for \(currentVpnProtocolFactory.self)", category: .connectionConnect)

            vpnManager.saveToPreferences { [weak self] error in
                guard let self else {
                    return
                }

                if let error {
                    setState(withError: error)
                    return
                }

                completion(vpnManager)
            }
        }
    }

    private func setState(withError error: Error? = nil) {
        if let error {
            log.error("VPN error: \(error)", category: .connection)
            state = .error(error)
            disconnectCompletion?()
            disconnectCompletion = nil
            stateChanged?()
            return
        }

        guard let vpnProtocol = currentVpnProtocol else {
            return
        }

        vpnStateConfiguration.determineActiveVpnState(vpnProtocol: vpnProtocol) { [weak self] result in
            guard let self, !self.quickReconnection else {
                return
            }

            switch result {
            case let .failure(error):
                setState(withError: error)
            case let .success((vpnManager, newState)):
                guard newState != state else {
                    return
                }

                switch newState {
                case .disconnecting:
                    quickReconnection = true
                    connectionQueue.asyncAfter(deadline: .now() + DomainConstants.UpdateTime.quickReconnectTime) {
                        let newState = self.vpnStateConfiguration.determineNewState(vpnManager: vpnManager)
                        switch newState {
                        case .connecting:
                            self.connectionQueue.asyncAfter(deadline: .now() + DomainConstants.UpdateTime.quickUpdateTime) {
                                self.updateState(vpnManager)
                            }
                        default:
                            self.updateState(vpnManager)
                        }
                    }

                default:
                    updateState(vpnManager)
                }
            }
        }
    }

    private func updateState(_ vpnManager: NEVPNManagerWrapper) {
        quickReconnection = false
        let oldState = state
        let newState = vpnStateConfiguration.determineNewState(vpnManager: vpnManager)
        guard newState != oldState else { return }
        state = newState
        log.info("VPN update state to \(state.logDescription)", category: .connection, event: .change, metadata: [
            "oldState": "\(oldState.logDescription)",
            "state": "\(newState.logDescription)",
            "currentProtocol": "\(optional: currentVpnProtocol)",
        ])

        #if os(macOS)
            // Prevents creating a plutonium tunnel config if the FF is disabled.
            if VPNFeatureFlagType.plutoniumMacOS.enabled {
                plutoniumUpdateTask?.cancel()
                plutoniumUpdateTask = Task {
                    do {
                        try await updatePlutoniumStateIfNeeded()
                    } catch let PlutoniumManagerError.saveFailed(error) {
                        log.error("Error while saving plutonium manager: \(error)")
                    } catch {
                        log.error("Error while updating plutonium state: \(error.localizedDescription)")
                    }
                }
            }
        #endif

        switch state {
        case .connecting:
            if !connectAllowed {
                log.info("VPN connection not allowed, will disconnect now.", category: .connection)
                disconnect {}
                return // prevent UI from updating with the connecting state
            }

            if let currentVpnProtocol, case VpnProtocol.ike = currentVpnProtocol, !self.propertiesManager.hasConnected {
                propertiesManager.hasConnected = true
            }
        case let .error(error):
            if case CommonVpnError.tlsServerVerification = error {
                disconnect {}
                SentryHelper.shared?.log(error: error)
                alertService?.push(alert: MITMAlert(messageType: .vpn))
                break
            }
            if case CommonVpnError.tlsInitialisation = error {
                disconnect {} // Prevent infinite connection loop
                break
            }
            fallthrough
        case .disconnected, .invalid:
            disconnectCompletion?()
            disconnectCompletion = nil
            setRemoteAuthenticationEndpoint(provider: nil)
            disconnectLocalAgent()
        case .connected:
            setRemoteAuthenticationEndpoint(provider: vpnManager.vpnConnection as? ProviderMessageSender)
            connectLocalAgent()
        default:
            break
        }

        stateChanged?()
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
    private func prepareManagers(forSetup _: Bool = false) {
        vpnStateConfiguration.determineActiveVpnProtocol(defaultToIke: true) { [weak self] vpnProtocol in
            guard let self else {
                return
            }

            currentVpnProtocol = vpnProtocol
            setState()

            notificationCenter.removeObserver(
                self,
                name: NSNotification.Name.NEVPNStatusDidChange,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(vpnStatusChanged),
                name: NSNotification.Name.NEVPNStatusDidChange,
                object: nil
            )
        }
    }

    @MainActor
    private func prepareManagers() async {
        let vpnProtocol = await vpnStateConfiguration.determineActiveVpnProtocol(defaultToIke: true)

        currentVpnProtocol = vpnProtocol
        setState()

        notificationCenter.removeObserver(
            self,
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(vpnStatusChanged),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }

    @objc
    private func vpnStatusChanged() {
        setState()
    }

    private func removeConfiguration(_ protocolFactory: VpnProtocolFactory, completionHandler: ((Error?) -> Void)?) {
        protocolFactory.vpnProviderManager(for: .configuration) { vpnManager, error in
            if let error {
                log.error("Error loading VPN Manager for removal: \(error)", category: .ui, metadata: ["factory": "\(protocolFactory)"])
                completionHandler?(CommonVpnError.removeVpnProfileFailed)
                return
            }
            guard let vpnManager else {
                completionHandler?(CommonVpnError.removeVpnProfileFailed)
                return
            }

            vpnManager.protocolConfiguration = nil
            vpnManager.removeFromPreferences(completionHandler: completionHandler)
        }
    }

    private func executeDisconnectionRequestWhenReady(request: @escaping () -> Void) {
        if let currentProtocol = currentVpnProtocol {
            log.debug("Proceeding with disconnection request immediately", category: .connection, metadata: ["currentVpnProtocol": "\(currentProtocol)"])
            request()
        } else {
            log.debug("Delaying disconnection request", category: .connection, metadata: ["currentVpnProtocol": "nil"])
            delayedDisconnectRequest = request
        }
    }

    #if os(macOS)
        private func updatePlutoniumStateIfNeeded() async throws {
            @Dependency(\.plutoniumManager) var plutoniumManager: PlutoniumManager
            @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
            guard FeatureFlagsRepository.shared
                .isEnabled(VPNFeatureFlagType.plutoniumMacOS, reloadValue: true), case .enabled = feature else {
                try await plutoniumManager.stop()
                return
            }

            switch state {
            case .connected:
                try await plutoniumManager.start()
            default:
                try await plutoniumManager.stop()
            }
        }
    #endif
}
