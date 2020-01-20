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
    var isOnDemandEnabled: Bool { get }
    
    func setOnDemand(_ enabled: Bool)
    func connect(configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func connectedDate() -> Date?
    func refreshState()
    func removeConfiguration(completionHandler: ((Error?) -> Void)?)
}

public protocol VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol
}

public class VpnManager: VpnManagerProtocol {
    
    private let connectionQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.connection", qos: .utility)
    private var vpnManager = NEVPNManager.shared()
    private let propertiesManager = PropertiesManager()
    
    private var connectAllowed = true
    
    private var disconnectCompletion: (() -> Void)?
    
    public private(set) var state: VpnState = .invalid
    public var stateChanged: (() -> Void)?
    
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
        connectAllowed = true
        connectionQueue.async { [weak self] in
            self?.prepareConnection(forConfiguration: configuration, completion: completion)
        }
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        connectAllowed = false
        connectionQueue.async { [weak self] in
            guard let `self` = self else { return }
            self.startDisconnect(completion: completion)
        }
    }
    
    public func removeConfiguration(completionHandler: ((Error?) -> Void)? = nil) {
        vpnManager.protocolConfiguration = nil
        vpnManager.removeFromPreferences(completionHandler: completionHandler)
    }
    
    public func connectedDate() -> Date? {
        // Returns a date if currently connected
        if case VpnState.connected(_) = state {
            return vpnManager.connection.connectedDate
        }
        return nil
    }
    
    public func refreshState() {
        setState()
    }
    
    // MARK: - Private functions
    // MARK: - Connecting
    private func prepareConnection(forConfiguration configuration: VpnManagerConfiguration,
                                   completion: @escaping () -> Void) {
        if state.volatileConnection {
            setState()
            return
        }
        
        PMLog.D("Loading connection configuration")
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
        guard connectAllowed else { return }
        
        PMLog.D("Configuring connection")
        vpnManager.protocolConfiguration = configuration
        vpnManager.onDemandRules = [NEOnDemandRuleConnect()]
        
        vpnManager.isOnDemandEnabled = propertiesManager.hasConnected
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
        guard connectAllowed else { return }
        
        PMLog.D("Loading connection configuration")
        vpnManager.loadFromPreferences { [weak self] loadError in
            guard let `self` = self else { return }
            
            if let loadError = loadError {
                self.setState(withError: loadError)
                return
            }
            
            guard self.connectAllowed else { return }
            do {
                PMLog.D("Starting VPN tunnel")
                try self.vpnManager.connection.startVPNTunnel()
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
        
        if propertiesManager.hasConnected {
            setOnDemand(false) { [weak self] in
                self?.vpnManager.connection.stopVPNTunnel()
            }
        } else {
            vpnManager.connection.stopVPNTunnel()
        }
        
        switch state {
        case .disconnected, .error, .invalid:
            setState() // ensures the completion handler is run if the state won't change after disconnecting, but must happen after turning setOnDemand off
        default:
            break
        }
    }
    
    // MARK: - Connect on demand
    private func setOnDemand(_ enabled: Bool, completion: @escaping () -> Void) {
        vpnManager.loadFromPreferences { [weak self] loadError in
            guard let `self` = self else { return }
            
            if let loadError = loadError {
                self.setState(withError: loadError)
                return
            }
            
            self.vpnManager.isOnDemandEnabled = enabled
            PMLog.D("On Demand set")
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
    
    func setState(withError error: Error? = nil) {
        state = newState(forManager: vpnManager, error: error)
        PMLog.D(state.logDescription)
        
        switch state {
        case .connecting:
            if !connectAllowed {
                disconnect {}
                return // prevent UI from updating with the connecting state
            }
        case .disconnected, .invalid, .error:
            if let completion = disconnectCompletion {
                disconnectCompletion = nil // Prevent calling this closure for the second time
                completion()
            }
        default:
            break
        }

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
