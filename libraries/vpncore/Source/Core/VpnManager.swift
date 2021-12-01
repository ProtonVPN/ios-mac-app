//
//  VpnManager.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import NetworkExtension

public protocol VpnManagerProtocol {

    var stateChanged: (() -> Void)? { get set }
    var state: VpnState { get }
    var localAgentStateChanged: (() -> Void)? { get set }
    var isLocalAgentConnected: Bool? { get }
    var currentVpnProtocol: VpnProtocol? { get }
    
    func isOnDemandEnabled(handler: @escaping (Bool) -> Void)
    func setOnDemand(_ enabled: Bool)
    func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func connectedDate(completion: @escaping (Date?) -> Void)
    func refreshState()
    func logsContent(for vpnProtocol: VpnProtocol, completion: @escaping (String?) -> Void)
    func logFile(for vpnProtocol: VpnProtocol) -> URL?
    func refreshManagers()
    func removeConfigurations(completionHandler: ((Error?) -> Void)?)

    func set(vpnAccelerator: Bool)
    func set(netShieldType: NetShieldType)
}

public protocol VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol
}

public class VpnManager: VpnManagerProtocol {
        
    private var quickReconnection = false
    
    private let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)
    
    private let ikeProtocolFactory: VpnProtocolFactory
    private let openVpnProtocolFactory: VpnProtocolFactory
    private let wireguardProtocolFactory: VpnProtocolFactory
    
    private let vpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory
    
    private var currentVpnProtocolFactory: VpnProtocolFactory? {
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

    public var currentVpnProtocol: VpnProtocol? {
        didSet {
            if oldValue == nil, let delayedRequest = delayedDisconnectRequest {
                delayedRequest()
                delayedDisconnectRequest = nil
            }
        }
    }
    public var stateChanged: (() -> Void)?

    public internal(set) var isLocalAgentConnected: Bool? {
        didSet {
            guard isLocalAgentConnected != oldValue else {
                return
            }
            localAgentStateChanged?()
        }
    }
    public var localAgentStateChanged: (() -> Void)?
    
    /// App group is used to read errors from OpenVPN in user defaults
    private let appGroup: String

    private let vpnStateConfiguration: VpnStateConfiguration

    let propertiesManager: PropertiesManagerProtocol
    let alertService: CoreAlertService?
    let vpnAuthentication: VpnAuthentication
    let vpnKeychain: VpnKeychainProtocol
    var localAgent: LocalAgent? {
        didSet {
            if localAgent == nil {
                isLocalAgentConnected = nil
            }
        }
    }
    
    public init(ikeFactory: VpnProtocolFactory, openVpnFactory: VpnProtocolFactory, wireguardProtocolFactory: VpnProtocolFactory, appGroup: String, vpnAuthentication: VpnAuthentication, vpnKeychain: VpnKeychainProtocol, propertiesManager: PropertiesManagerProtocol, vpnStateConfiguration: VpnStateConfiguration, alertService: CoreAlertService? = nil, vpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory) {
        self.ikeProtocolFactory = ikeFactory
        self.openVpnProtocolFactory = openVpnFactory
        self.wireguardProtocolFactory = wireguardProtocolFactory
        self.appGroup = appGroup
        self.alertService = alertService
        self.vpnAuthentication = vpnAuthentication
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.vpnStateConfiguration = vpnStateConfiguration
        self.vpnCredentialsConfiguratorFactory = vpnCredentialsConfiguratorFactory
        
        prepareManagers()
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
    
    public func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        disconnect { [weak self] in
            self?.currentVpnProtocol = configuration.vpnProtocol
            log.info("About to start connection process", category: .connectionConnect)
            self?.connectAllowed = true
            self?.connectionQueue.async { [weak self] in
                self?.prepareConnection(forConfiguration: configuration, completion: completion)
            }
        }
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        executeDisconnectionRequestWhenReady { [weak self] in
            self?.connectAllowed = false
            self?.connectionQueue.async { [weak self] in
                guard let `self` = self else { return }
                self.startDisconnect(completion: completion)
            }
        }
    }
    
    public func removeConfigurations(completionHandler: ((Error?) -> Void)? = nil) {
        let dispatchGroup = DispatchGroup()
        var error: Error?
        var successful = false // mark as success if at least one removal succeeded
        
        dispatchGroup.enter()
        removeConfiguration(ikeProtocolFactory) { e in
            if e != nil {
                error = e
            } else {
                successful = true
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        removeConfiguration(openVpnProtocolFactory) { e in
            if e != nil {
                error = e
            } else {
                successful = true
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            completionHandler?(successful ? nil : error)
        }
    }
    
    public func connectedDate(completion: @escaping (Date?) -> Void) {
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            completion(nil)
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] vpnManager, error in
            guard let `self` = self else {
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
                completion(vpnManager.connection.connectedDate)
            } else {
                completion(nil)
            }
        }
    }
    
    public func refreshState() {
        setState()
    }
    
    public func logsContent(for vpnProtocol: VpnProtocol, completion: @escaping (String?) -> Void) {
        switch vpnProtocol {
        case .ike:
            ikeProtocolFactory.logs(completion: completion)
        case .openVpn:
            openVpnProtocolFactory.logs(completion: completion)
        case .wireGuard:
            wireguardProtocolFactory.logs(completion: completion)
        }
    }
    
    public func logFile(for vpnProtocol: VpnProtocol) -> URL? {
        switch vpnProtocol {
        case .ike:
            return ikeProtocolFactory.logFile()
        case .openVpn:
            return openVpnProtocolFactory.logFile()
        case .wireGuard:
            return wireguardProtocolFactory.logFile()
        }
    }
    
    public func refreshManagers() {
        // Stop recieving status updates until the manager is prepared
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        
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
            guard let `self` = self else { return }
            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            
            do {
                let protocolConfiguration = try currentVpnProtocolFactory.create(configuration)
                let credentialsConfigurator = self.vpnCredentialsConfiguratorFactory.getCredentialsConfigurator(for: configuration.vpnProtocol)
                
                credentialsConfigurator.prepareCredentials(for: protocolConfiguration, configuration: configuration) { protocolConfigurationWithCreds in
                    self.configureConnection(forProtocol: protocolConfigurationWithCreds, vpnManager: vpnManager) {
                        self.startConnection(completion: completion)
                    }
                }
                
            } catch {
                log.error("\(error)", category: .ui)
            }
        }
    }
    
    private func configureConnection(forProtocol configuration: NEVPNProtocol,
                                     vpnManager: NEVPNManager,
                                     completion: @escaping () -> Void) {
        guard connectAllowed else { return }
        
        log.info("Configuring connection", category: .connectionConnect)
        
        // MARK: - KillSwitch configuration
        #if os(OSX)
        configuration.includeAllNetworks = propertiesManager.killSwitch
        configuration.excludeLocalNetworks = propertiesManager.excludeLocalNetworks
        #elseif os(iOS)
        if #available(iOS 14, *) {
            configuration.includeAllNetworks = propertiesManager.killSwitch
        }
        if #available(iOS 14.2, *) {
            configuration.excludeLocalNetworks = propertiesManager.excludeLocalNetworks
        }
        #endif

        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        vpnManager.isOnDemandEnabled = hasConnected
        vpnManager.isEnabled = true
        
        let saveToPreferences = {
            vpnManager.saveToPreferences { [weak self] saveError in
                guard let `self` = self else { return }
                if let saveError = saveError {
                    self.setState(withError: saveError)
                    return
                }
                
                completion()
            }
        }
        
        // Any non-personal VPN configuration with includeAllNetworks enabled, prevents IKEv2 (with includeAllNetworks) from connecting. #VPNAPPL-566
        if #available(OSX 10.15, iOS 14, *), configuration.includeAllNetworks && configuration.isKind(of: NEVPNProtocolIKEv2.self) {
            self.removeConfiguration(self.openVpnProtocolFactory, completionHandler: { _ in
                self.removeConfiguration(self.wireguardProtocolFactory, completionHandler: { _ in
                    saveToPreferences()
                })
            })
        } else {
            saveToPreferences()
        }
                
    }
    
    private func startConnection(completion: @escaping () -> Void) {
        guard connectAllowed, let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        log.info("Loading connection configuration", category: .connectionConnect)
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let `self` = self else { return }
            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            guard self.connectAllowed else { return }
            do {
                log.info("Starting VPN tunnel", category: .connectionConnect)
                try vpnManager.connection.startVPNTunnel()
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
    
    private func stopTunnelOrRunCompletion(vpnManager: NEVPNManager) {
        switch self.state {
        case .disconnected, .error, .invalid:
            disconnectCompletion?() // ensures the completion handler is run already disconnected
            disconnectCompletion = nil
        default:
            vpnManager.connection.stopVPNTunnel()
        }
    }
    
    // MARK: - Connect on demand
    private func setOnDemand(_ enabled: Bool, completion: @escaping (NEVPNManager) -> Void) {
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let `self` = self else { return }
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
                guard let `self` = self else { return }
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
    
    private func updateState(_ vpnManager: NEVPNManager) {
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
            disconnectLocalAgent()
        case .connected:
            self.connectLocalAgent()
        default:
            break
        }

        self.stateChanged?()
    }
    
    // swiftlint:enable cyclomatic_complexity function_body_length

    /*
     *  Upon initiation of VPN manager, VPN configuration from manager needs
     *  to be loaded in order for storing of further configurations to work.
     */
    private func prepareManagers() {
        vpnStateConfiguration.determineActiveVpnProtocol { [weak self] vpnProtocol in
            guard let self = self else {
                return
            }

            self.currentVpnProtocol = vpnProtocol
            self.setState()

            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.vpnStatusChanged),
                                                   name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
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
