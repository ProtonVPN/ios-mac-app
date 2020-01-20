//
//  VpnManager.swift
//  ProtonVPN
//
//  Created by Hrvoje Bušić on 29/07/2017.
//  Copyright © 2017 ProtonVPN. All rights reserved.
//

import NetworkExtension

public protocol VpnManagerProtocol {
    
    var stateChanged: (() -> ())? { get set }
    var state: VpnState { get }
    var isOnDemandEnabled: Bool { get }
    
    func setOnDemand(_ enabled: Bool)
    func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func connectedDate() -> Date?
}

public class VpnManager: VpnManagerProtocol {
    
    private let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)
    private let vpnManager = NEVPNManager.shared()
    
    private(set) public var state: VpnState = .invalid
    public var stateChanged: (() -> ())?
    
    public var isOnDemandEnabled: Bool {
        return vpnManager.isOnDemandEnabled
    }
    
    public init() {
        setState()
        startObserving()
        startupRoutine()
    }
    
    public func setOnDemand(_ enabled: Bool) {
        connectionQueue.async { [weak self] in
            self?.setOnDemand(enabled) {}
        }
    }
    
    public func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        connectionQueue.async { [weak self] in
            self?.prepareConnection(forConfiguration: configuration, completion: completion)
        }
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        connectionQueue.async { [weak self] in
            guard let `self` = self else { return }
            
            if !self.state.stableConnection && !self.state.volatileConnection {
                completion()
                return
            }
            
            self.startDisconnect(completion: completion)
        }
    }
    
    public func removeConfiguration() {
        vpnManager.protocolConfiguration = nil
        vpnManager.removeFromPreferences()
    }
    
    public func connectedDate() -> Date? {
        // Returns a date if currently connected
        if case VpnState.connected(_) = state {
            return vpnManager.connection.connectedDate
        }
        return nil
    }
    
    // MARK:- Private functions
    // MARK:- Connecting
    private func prepareConnection(forConfiguration configuration: VpnManagerConfiguration,
                                   completion: @escaping () -> Void) {
        if state.volatileConnection {
            setState()
            return
        }
        
        vpnManager.loadFromPreferences { [weak self] loadError in
            guard let `self` = self else { return }
            
            if let loadError = loadError {
                self.setState(withError: loadError)
                return
            }
            
            self.configureConnection(forProtocol: IkeProtocolFactory.create(configuration),
                                     completion: completion)
        }
    }
    
    private func configureConnection(forProtocol configuration: NEVPNProtocol,
                                     completion: @escaping () -> Void) {
        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        vpnManager.isOnDemandEnabled = UserDefaults.standard.bool(forKey: CoreAppConstants.userDefaults.connectOnDemand)
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
        vpnManager.loadFromPreferences { [weak self] loadError in
            guard let `self` = self else { return }
            
            if let loadError = loadError {
                self.setState(withError: loadError)
                return
            }
            
            do {
                try self.vpnManager.connection.startVPNTunnel()
                completion()
            } catch {
                self.setState(withError: error)
            }
        }
    }
    
    // MARK:- Disconnecting
    private func startDisconnect(completion: @escaping (() -> Void)) {
        if UserDefaults.standard.bool(forKey: CoreAppConstants.userDefaults.connectOnDemand) {
            setOnDemand(false) { [weak self] in
                self?.vpnManager.connection.stopVPNTunnel()
                completion()
            }
        } else {
            vpnManager.connection.stopVPNTunnel()
            completion()
        }
    }
    
    // MARK:- Connect on demand
    private func setOnDemand(_ enabled: Bool, completion: @escaping () -> Void) {
        vpnManager.loadFromPreferences { [weak self] loadError in
            guard let `self` = self else { return }
            
            if let loadError = loadError {
                self.setState(withError: loadError)
                return
            }
            
            self.vpnManager.isOnDemandEnabled = enabled
            self.vpnManager.saveToPreferences { [weak self] saveError in
                guard let `self` = self else { return }
                
                if let saveError = saveError {
                    self.setState(withError: saveError)
                    return
                }
                
                completion()
            }
        }
    }
    
    private func setState(withError error: Error? = nil) {
        state = newState(forManager: vpnManager, error: error)
        PMLog.D(state.logDescription)
        stateChanged?()
    }
    
    private func newState(forManager vpnManager: NEVPNManager, error: Error? = nil) -> VpnState {
        if let error = error {
            PMLog.ET("VPN error: \(error.localizedDescription)")
            return .error(error)
        }
        
        let status = vpnManager.connection.status.rawValue
        let username = vpnManager.protocolConfiguration?.username ?? ""
        let serverAddress = vpnManager.protocolConfiguration?.serverAddress ?? ""
        
        switch status {
        case 0:
            return .invalid
        case 1:
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
    
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusChanged),
                                               name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    /*
     *  Upon initiation of VPN manager, VPN configuration from manager needs
     *  to be loaded in order for storing of further configurations to work.
     */
    private func startupRoutine() {
        vpnManager.loadFromPreferences { [weak self] error in
            guard let `self` = self else { return }
            
            if let error = error {
                self.setState(withError: error)
            }
        }
    }
    
    @objc private func vpnStatusChanged() {
        setState()
    }
}
