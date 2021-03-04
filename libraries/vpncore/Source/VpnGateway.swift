//
//  VpnGateway.swift
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

import Foundation

public enum ConnectionStatus {
    
    case disconnected
    case connecting
    case connected
    case disconnecting
    
    static func forAppState(_ appState: AppState) -> ConnectionStatus {
        switch appState {
        case .disconnected, .aborted, .error:
            return .disconnected
        case .preparingConnection, .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .disconnecting
        }
    }
}

public enum ResolutionUnavailableReason {

    case upgrade(Int)
    case maintenance
    case existingConnection
}

public enum RestrictedServerGroup {
    
    case all
    case country(code: String)
}

public enum ServerSelection {
    
    case fastest
    case random
}

public protocol VpnGatewayProtocol: class {
    
    var connection: ConnectionStatus { get }
    var lastConnectionRequest: ConnectionRequest? { get }

    func userTier() throws -> Int
    func changeActiveServerType(_ serverType: ServerType)
    func autoConnect()
    func quickConnect()
    func quickConnectConnectionRequest() -> ConnectionRequest
    func connectTo(country countryCode: String, ofType serverType: ServerType)
    func connectTo(server: ServerModel)
    func connectTo(profile: Profile)
    func retryConnection()
    func reconnect(with netShieldType: NetShieldType)
    func reconnect(with vpnProtocol: VpnProtocol)
    func connect(with request: ConnectionRequest?)
    func stopConnecting(userInitiated: Bool)
    func disconnect()
    func disconnect(completion: @escaping () -> Void)
    
}

public protocol VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol
}

public class VpnGateway: VpnGatewayProtocol {
    
    private enum ConnectionType {
        case quick
        case auto
        case country(code: String, type: ServerType)
        case server(ServerModel)
        case profile(Profile)
    }
    
    private let vpnApiService: VpnApiService
    private let appStateManager: AppStateManager
    private let serverManager: ServerManager
    private let profileManager: ProfileManager
    private let serverTierChecker: ServerTierChecker
    private let vpnKeychain: VpnKeychainProtocol
    
    private let serverStorage: ServerStorage = ServerStorageConcrete()
    private let propertiesManager = PropertiesManager()
    
    private let siriHelper: SiriHelperProtocol?

    private var tier: Int
    
    private var globalVpnProtocol: VpnProtocol {
        return propertiesManager.vpnProtocol
    }
    
    private var serverTypeToggle: ServerType {
        return propertiesManager.secureCoreToggle ? .secureCore : .standard
    }
    
    private var connectionPreparer: VpnConnectionPreparer?
    
    public static let connectionChanged = Notification.Name("VpnGatewayConnectionChanged")
    public static let activeServerTypeChanged = Notification.Name("VpnGatewayActiveServerTypeChanged")
    
    public weak var alertService: CoreAlertService? {
        didSet {
            serverTierChecker.alertService = alertService
        }
    }
    
    public var connection: ConnectionStatus {
        return ConnectionStatus.forAppState(appStateManager.state)
    }
    
    public var lastConnectionRequest: ConnectionRequest? {
        return propertiesManager.lastConnectionRequest
    }
    
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private var netShieldType: NetShieldType {
        return netShieldPropertyProvider.netShieldType
    }
    
    // FUTUREDO: Use factory
    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, siriHelper: SiriHelperProtocol? = nil, netShieldPropertyProvider: NetShieldPropertyProvider) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.siriHelper = siriHelper
        self.netShieldPropertyProvider = netShieldPropertyProvider
        do {
            tier = try vpnKeychain.fetch().maxTier
        } catch {
            // default tier was max before, probably not needed anymore
            tier = CoreAppConstants.VpnTiers.free
        }
        
        serverManager = ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
        profileManager = ProfileManager.shared
        serverTierChecker = ServerTierChecker(alertService: alertService, vpnKeychain: vpnKeychain)
        
        if case AppState.connected(_) = appStateManager.state, let activeServer = appStateManager.activeConnection()?.server {
            changeActiveServerType(activeServer.serverType)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appStateChanged),
                                               name: appStateManager.stateChange, object: nil)
    }
    
    public func userTier() throws -> Int {
        let tier = try vpnKeychain.fetch().maxTier
        return tier
    }
    
    public func changeActiveServerType(_ serverType: ServerType) {
        guard serverTypeToggle != serverType else { return }
        
        propertiesManager.secureCoreToggle = serverType == .secureCore
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.activeServerTypeChanged, object: self.connection)
        }
    }
    
    public func autoConnect() {
        appStateManager.isOnDemandEnabled { [weak self] enabled in
            guard let `self` = self, !enabled else { return }
        
            if let autoConnectProfileId = self.propertiesManager.autoConnect.profileId, let profile = self.profileManager.profile(withId: autoConnectProfileId) {
                self.connectTo(profile: profile)
            } else {
                self.quickConnect()
            }
        }
    }
    
    public func quickConnect() {
        connect(with: quickConnectConnectionRequest())
    }
    
    public func quickConnectConnectionRequest() -> ConnectionRequest {
        if let quickConnectProfileId = propertiesManager.quickConnect, let profile = profileManager.profile(withId: quickConnectProfileId) {
            return profile.connectionRequest(withDefaultNetshield: netShieldType)
        } else {
            return ConnectionRequest(serverType: serverTypeToggle, connectionType: .fastest, vpnProtocol: globalVpnProtocol, netShieldType: netShieldType, profileId: nil)
        }
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(countryCode, .fastest), vpnProtocol: globalVpnProtocol, netShieldType: netShieldType, profileId: nil)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(server: ServerModel) {
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(server.countryCode, countryType), vpnProtocol: globalVpnProtocol, netShieldType: netShieldType, profileId: nil)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(profile: Profile) {
        connect(with: profile.connectionRequest(withDefaultNetshield: netShieldType))
    }
    
    public func retryConnection() {
        connect(with: lastConnectionRequest)
    }
    
    public func reconnect(with netShieldType: NetShieldType) {
        connect(with: lastConnectionRequest?.withChanged(netShieldType: netShieldType))
    }
    
    public func reconnect(with vpnProtocol: VpnProtocol) {
        disconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(CoreAppConstants.protocolChangeDelay), execute: { // Delay enhances reconnection success rate
                self.connect(with: self.lastConnectionRequest?.withChanged(vpnProtocol: vpnProtocol))
            })
        }
    }
    
    public func connect(with request: ConnectionRequest?) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        propertiesManager.lastConnectionRequest = request
        
        guard let request = request else {
            connect(with: globalVpnProtocol, server: appStateManager.activeConnection()?.server, netShieldType: netShieldType)
            return
        }
        
        connect(with: request.vpnProtocol, server: selectServer(connectionRequest: request), netShieldType: request.netShieldType)
    }
    
    private func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        do {
            let currentUserTier = try self.userTier() // accessing from the keychain for each server is very expensive
            
            let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType
            
            let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: serverManager.grouping(for: type), appStateGetter: {
                return self.appStateManager.state
            })
            selector.changeActiveServerType = { [self] serverType in
                self.changeActiveServerType(serverType)
            }
            selector.notifyResolutionUnavailable = { [self] forSpecificCountry, type, reason in
                self.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
            }
            
            return selector.selectServer(connectionRequest: connectionRequest)
            
        } catch {
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
    
    public func stopConnecting(userInitiated: Bool) {
        PMLog.D("Connecting cancelled, userInitiated: \(userInitiated)")
        connectionPreparer = nil
        appStateManager.cancelConnectionAttempt()
    }
    
    public func disconnect() {
        disconnect {}
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        let completionWrapper: () -> Void = { [weak self] in
            completion()
            
            guard let `self` = self else {
                return
            }
            
            self.vpnApiService.refreshServerInfoIfIpChanged(lastKnownIp: self.propertiesManager.userIp, success: { [weak self] properties in
                guard let `self` = self else { return }
                
                self.propertiesManager.userIp = properties.ip
                self.serverStorage.store(properties.serverModels)
                
                ProfileManager.shared.refreshProfiles()
            }, failure: { _ in
                // Ignore failures as this is a non-critical call
            })
        }
        
        siriHelper?.donateDisconnect()
        appStateManager.disconnect(completion: completionWrapper)
    }
    
    // MARK: - Private functions
    
    private func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        stopConnecting(userInitiated: false)
        serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
    }
    
    private func connect(with vpnProtocol: VpnProtocol, server: ServerModel?, netShieldType: NetShieldType) {
        guard let server = server else {
            return
        }
        
        appStateManager.prepareToConnect()
        
        connectionPreparer = VpnConnectionPreparer(appStateManager: appStateManager, vpnApiService: vpnApiService, alertService: alertService, serverTierChecker: serverTierChecker, vpnKeychain: vpnKeychain)
        connectionPreparer?.connect(withProtocol: vpnProtocol, server: server, netShieldType: netShieldType)
    }
    
    @objc private func appStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.connectionChanged, object: self.connection)
        }
    }
}
