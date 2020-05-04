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
    
    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, siriHelper: SiriHelperProtocol? = nil) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.siriHelper = siriHelper
        
        serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.max, serverStorage: ServerStorageConcrete())
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
            return profile.connectionRequest
        } else {
            return ConnectionRequest(serverType: serverTypeToggle, connectionType: .fastest, vpnProtocol: globalVpnProtocol)
        }
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(countryCode, .fastest), vpnProtocol: globalVpnProtocol)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(server: ServerModel) {
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(server.countryCode, countryType), vpnProtocol: globalVpnProtocol)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(profile: Profile) {
        connect(with: profile.connectionRequest)
    }
    
    public func retryConnection() {
        connect(with: lastConnectionRequest)
    }
    
    public func connect(with request: ConnectionRequest?) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        propertiesManager.lastConnectionRequest = request
        
        guard let request = request else {
            connect(with: globalVpnProtocol, server: appStateManager.activeConnection()?.server)
            return
        }
        
        connect(with: request.vpnProtocol, server: selectServer(connectionRequest: request))
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
    private func filter(servers: [ServerModel], forSpecificCountry: Bool, type: ServerType) -> [ServerModel] {
        do {
            let userTier = try self.userTier() // accessing from the keychain for each server is very expensive
            
            let serversWithoutUpgrades = servers.filter { $0.tier <= userTier }
            if serversWithoutUpgrades.isEmpty {
                notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: .upgrade(servers.reduce(Int.max, { (lowestTier, server) -> Int in
                    return lowestTier > server.tier ? server.tier : lowestTier
                })))
                return []
            }
            
            let serversWithoutMaintenance = serversWithoutUpgrades.filter { !$0.underMaintenance }
            if serversWithoutMaintenance.isEmpty {
                notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: .maintenance)
                return []
            }
            
            return serversWithoutMaintenance
        } catch {
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return []
        }
    }
    
    private func userAccessibleGrouping(_ type: ServerType, countryCode: String) -> CountryGroup? {
        return serverManager.grouping(for: type)
            .filter({ $0.0.countryCode == countryCode })
            .first
    }
    
    private func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        // use the ui to determine connection type if unspecified
        let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType
        
        let sortedServers: [ServerModel]
        let forSpecificCountry: Bool
        if case ConnectionRequestType.country(let countryCode, _) = connectionRequest.connectionType { // servers of a single country
            guard let countryGroup = userAccessibleGrouping(type, countryCode: countryCode) else {
                return nil
            }
            sortedServers = countryGroup.1.sorted(by: { ($1.tier, $0.score) < ($0.tier, $1.score) }) // sort by highest tier first, then lowest score
            forSpecificCountry = true
        } else { // all servers
            sortedServers = serverManager.grouping(for: type)
                .map({ $0.1 })
                .flatMap({ $0 })
                .sorted(by: { ($1.tier, $0.score) < ($0.tier, $1.score) }) // sort by highest tier first, then lowest score
            forSpecificCountry = false
        }
            
        let servers = filter(servers: sortedServers, forSpecificCountry: forSpecificCountry, type: type)
        
        guard !servers.isEmpty else {
            return nil
        }
        
        let filtered: [ServerModel]
        if type != .tor {
            filtered = servers.filter { $0.feature.contains(.tor) == false } // only include tor servers if those are the servers we explicitly want
        } else {
            filtered = servers
        }
        
        changeActiveServerType(type)
        
        if !filtered.isEmpty {
            return pickServer(from: filtered, connectionRequest: connectionRequest)
        }
        
        if case AppState.preparingConnection = self.appStateManager.state {
            return pickServer(from: servers, connectionRequest: connectionRequest)
        } else {
            return nil
        }
    }
    
    private func pickServer(from servers: [ServerModel], connectionRequest: ConnectionRequest) -> ServerModel? {
        switch connectionRequest.connectionType {
        case .fastest:
            return servers.first
        case .random:
            return servers[Int(arc4random_uniform(UInt32(servers.count)))]
        case .country(_, let countryType):
            switch countryType {
            case .fastest:
                return servers.first
            case .random:
                return servers[Int(arc4random_uniform(UInt32(servers.count)))]
            case .server(let server):
                return server
            }
        }
    }
    
    private func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        stopConnecting(userInitiated: false)
        serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
    }
    
    private func connect(with vpnProtocol: VpnProtocol, server: ServerModel?) {
        guard let server = server else {
            return
        }
        
        appStateManager.prepareToConnect()
        
        connectionPreparer = VpnConnectionPreparer(appStateManager: appStateManager, vpnApiService: vpnApiService, alertService: alertService, serverTierChecker: serverTierChecker, vpnKeychain: vpnKeychain)
        connectionPreparer?.connect(withProtocol: vpnProtocol, server: server)
    }
    
    @objc private func appStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.connectionChanged, object: self.connection)
        }
    }
}
