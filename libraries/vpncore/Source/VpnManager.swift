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
    var currentVpnProtocol: VpnProtocol? { get }
    
    func isOnDemandEnabled(handler: @escaping (Bool) -> Void)
    func setOnDemand(_ enabled: Bool)
    func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func connectedDate(completion: @escaping (Date?) -> Void)
    func refreshState()
    func logsContent(for vpnProtocol: VpnProtocol, completion: @escaping (String?) -> Void)
    func logFile(for vpnProtocol: VpnProtocol, completion: @escaping (URL?) -> Void)
    func refreshManagers()
    func removeConfigurations(completionHandler: ((Error?) -> Void)?)
}

public protocol VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol
}

public class VpnManager: VpnManagerProtocol {
        
    private var quickReconnection = false
    
    private let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)
    private let propertiesManager = PropertiesManager()
    
    private var ikeProtocolFactory: VpnProtocolFactory
    private var openVpnProtocolFactory: VpnProtocolFactory
    private var currentVpnProtocolFactory: VpnProtocolFactory? {
        guard let currentVpnProtocol = currentVpnProtocol else {
            return nil
        }
        
        switch currentVpnProtocol {
        case .ike:
            return ikeProtocolFactory
        case .openVpn:
            return openVpnProtocolFactory
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
    
    /// App group is used to read errors from OpenVPN in user defaults
    private let appGroup: String
    private let alertService: CoreAlertService?
    
    public init(ikeFactory: VpnProtocolFactory, openVpnFactory: VpnProtocolFactory, appGroup: String, alertService: CoreAlertService? = nil) {
        self.ikeProtocolFactory = ikeFactory
        self.openVpnProtocolFactory = openVpnFactory
        self.appGroup = appGroup
        self.alertService = alertService
        
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
            
            PMLog.D("About to start connection process")
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
        }
    }
    
    public func logFile(for vpnProtocol: VpnProtocol, completion: @escaping (URL?) -> Void) {
        switch vpnProtocol {
        case .ike:
            ikeProtocolFactory.logFile(completion: completion)
        case .openVpn:
            openVpnProtocolFactory.logFile(completion: completion)
        }
    }
    
    public func refreshManagers() {
        // Stop recieving status updates until the manager is prepared
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        
        prepareManagers()
    }
    
    // MARK: - Private functions
    // MARK: - Connecting
    private func prepareConnection(forConfiguration configuration: VpnManagerConfiguration,
                                   completion: @escaping () -> Void) {
        if state.volatileConnection {
            setState()
            return
        }
        
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        PMLog.D("Creating connection configuration")
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let `self` = self else { return }
            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            
            do {
                let protocolConfiguration = try currentVpnProtocolFactory.create(configuration)
                self.configureConnection(forProtocol: protocolConfiguration,
                                         vpnManager: vpnManager,
                                         completion: completion)
            } catch {
                PMLog.ET(error)
            }
        }
    }
    
    private func configureConnection(forProtocol configuration: NEVPNProtocol,
                                     vpnManager: NEVPNManager,
                                     completion: @escaping () -> Void) {
        guard connectAllowed else { return }
        
        PMLog.D("Configuring connection")
        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        vpnManager.isOnDemandEnabled = hasConnected
        vpnManager.isEnabled = true
        
        vpnManager.saveToPreferences { [weak self] saveError in
            guard let `self` = self else { return }
            if let saveError = saveError {
                self.setState(withError: saveError)
                return
            }
            
            self.startConnection(completion: completion)
        }
    }
    
    private func startConnection(completion: @escaping () -> Void) {
        guard connectAllowed, let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        PMLog.D("Loading connection configuration")
        currentVpnProtocolFactory.vpnProviderManager(for: .configuration) { [weak self] vpnManager, error in
            guard let `self` = self else { return }
            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            guard self.connectAllowed else { return }
            
            do {
                PMLog.D("Starting VPN tunnel")
                try vpnManager.connection.startVPNTunnel()
                completion()
            } catch {
                self.setState(withError: error)
            }
        }
    }
    
    // MARK: - Disconnecting
    private func startDisconnect(completion: @escaping (() -> Void)) {
        PMLog.D("Closing VPN tunnel")
        
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
            PMLog.D("On Demand set: \(enabled ? "On" : "Off")")
            
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
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    private func setState(withError error: Error? = nil) {
        if let error = error {
            PMLog.ET("VPN error: \(error.localizedDescription)")
            state = .error(error)
            disconnectCompletion?()
            disconnectCompletion = nil
            self.stateChanged?()
            return
        }
        
        guard let currentVpnProtocolFactory = currentVpnProtocolFactory else {
            return
        }
        
        currentVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] vpnManager, error in
            guard let `self` = self, !self.quickReconnection else { return }
            if let error = error {
                self.setState(withError: error)
                return
            }
            guard let vpnManager = vpnManager else { return }
            
            let newState = self.newState(forManager: vpnManager)

            guard newState != self.state else { return }
            
            switch newState {
            case .disconnecting:
                self.quickReconnection = true
                self.connectionQueue.asyncAfter(deadline: .now() + CoreAppConstants.UpdateTime.quickReconnectTime) {
                    let newState = self.newState(forManager: vpnManager)
                    switch newState {
                    case .connecting:
                        self.connectionQueue.asyncAfter(deadline: .now() + CoreAppConstants.UpdateTime.quickUpdateTime) {
                            self.updateState(vpnManager)
                        }
                        break
                    default:
                        self.updateState(vpnManager)
                    }
                }
                return
            default:
                self.updateState(vpnManager)
            }
        }
    }
    
    private func updateState( _ vpnManager: NEVPNManager ) {
        quickReconnection = false
        let newState = self.newState(forManager: vpnManager)
        guard newState != self.state else { return }
        self.state = newState
        PMLog.D(self.state.logDescription)
        
        switch self.state {
        case .connecting:
            if !self.connectAllowed {
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
        default:
            break
        }

        self.stateChanged?()
    }
    
    
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    private func newState(forManager vpnManager: NEVPNManager) -> VpnState {
        let status = vpnManager.connection.status.rawValue
        let username = vpnManager.protocolConfiguration?.username ?? ""
        let serverAddress = vpnManager.protocolConfiguration?.serverAddress ?? ""
        
        switch status {
        case 0:
            return .invalid
        case 1:
            if let error = lastError() {
                switch error {
                case ProtonVpnError.tlsServerVerification, ProtonVpnError.tlsInitialisation:
                    return .error(error)
                default: break
                }
            }
            return .disconnected
        case 2:
            return .connecting(ServerDescriptor(username: username, address: serverAddress))
        case 3:
            return .connected(ServerDescriptor(username: username, address: serverAddress))
        case 4:
            return .reasserting(ServerDescriptor(username: username, address: serverAddress))
        default:
            return .disconnecting(ServerDescriptor(username: username, address: serverAddress))
        }
    }
    
    /// Get last VPN connectino error.
    /// Currently detects only errors from OpenVPN connection.
    private func lastError() -> Error? {
        let defaults = UserDefaults(suiteName: appGroup)
        let errorKey = "TunnelKitLastError"
        guard let lastError = defaults?.object(forKey: errorKey) else {
            return nil
        }
        if let error = lastError as? String {
            switch error {
            case "tlsServerVerification": return ProtonVpnError.tlsServerVerification
            case "tlsInitialization": return ProtonVpnError.tlsInitialisation
            default: break
            }
        }
        if let errorString = lastError as? String {
            return NSError(code: 0, localizedDescription: errorString)
        }
        return nil
    }
    
    /*
     *  Upon initiation of VPN manager, VPN configuration from manager needs
     *  to be loaded in order for storing of further configurations to work.
     */
    private func prepareManagers() {
        let dispatchGroup = DispatchGroup()
        
        var openVpnCurrentlyActive = false
        
        dispatchGroup.enter()
        ikeProtocolFactory.vpnProviderManager(for: .status) { _, _ in
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        openVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] manager, error in
            guard let `self` = self, let manager = manager else {
                dispatchGroup.leave()
                return
            }
            
            let state = self.newState(forManager: manager)
            if state.stableConnection || state.volatileConnection { // state is connected or in some kind of transition state
                openVpnCurrentlyActive = true
            }
            
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let `self` = self else { return }
            
            // OpenVPN takes precedence but if neither are active, then it should remain unchanged
            if openVpnCurrentlyActive {
                self.currentVpnProtocol = .openVpn(.undefined)
            } else {
                self.currentVpnProtocol = .ike
            }
            
            self.setState()
            
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
                PMLog.ET(error)
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
