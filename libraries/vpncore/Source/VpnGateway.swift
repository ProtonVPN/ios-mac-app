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
    
    var activeServerType: ServerType { get }
    var connectingCellDelegate: ConnectingCellDelegate? { get set }
    var connection: ConnectionStatus { get }
    var activeIp: String? { get }
    var activeServer: ServerModel? { get }
    var activeConnectionRequest: ConnectionRequest? { get }

    func userTier() throws -> Int
    func changeActiveServerType(_ serverType: ServerType)
    func autoConnect()
    func quickConnect()
    func connectTo(country countryCode: String, ofType serverType: ServerType)
    func connectTo(server: ServerModel)
    func connectTo(profile: Profile)
    func retryConnection()
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
    
    private var connectionPreparer: VpnConnectionPreparer?
    
    private let siriHelper: SiriHelperProtocol?
    
    public static let connectionChanged = Notification.Name("VpnGatewayConnectionChanged")
    public static let activeServerTypeChanged = Notification.Name("VpnGatewayActiveServerTypeChanged")
    
    public weak var alertService: CoreAlertService? {
        didSet {
            serverTierChecker.alertService = alertService
        }
    }
    
    public var activeServerType: ServerType {
        return propertiesManager.secureCoreToggle ? .secureCore : .standard
    }
    
    private var lastConnectionType: ConnectionType?
    
    public weak var connectingCellDelegate: ConnectingCellDelegate?
    
    public var connection: ConnectionStatus {
        return ConnectionStatus.forAppState(appStateManager.state)
    }
    
    public var activeIp: String? {
        return appStateManager.activeIp
    }
    
    public var activeServer: ServerModel? {
        return appStateManager.activeServer
    }
    
    public var activeConnectionRequest: ConnectionRequest? {
        return propertiesManager.lastConnectionRequest
    }
    
    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, siriHelper: SiriHelperProtocol? = nil) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.siriHelper = siriHelper
        
        serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
        profileManager = ProfileManager.shared
        serverTierChecker = ServerTierChecker(alertService: alertService, vpnKeychain: vpnKeychain)
        
        if case AppState.connected(_) = appStateManager.state, let activeServer = appStateManager.activeServer {
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
        guard activeServerType != serverType else { return }
        
        propertiesManager.secureCoreToggle = serverType == .secureCore
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.activeServerTypeChanged, object: self.connection)
        }
    }
    
    public func autoConnect() {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        lastConnectionType = .auto
        
        if let autoConnectProfileId = propertiesManager.autoConnect.profileId, let profile = profileManager.profile(withId: autoConnectProfileId) {
            connectTo(profile: profile)
        } else {
            let connectionRequest = ConnectionRequest(serverType: activeServerType, connectionType: .fastest)
            propertiesManager.lastConnectionRequest = connectionRequest
            
            let selectServerClosure: ([SessionModel]?) -> (ServerModel?) = { [weak self] sessions in
                guard let `self` = self else { return nil }
                return self.selectServer(connectionRequest: connectionRequest, sessions: sessions)
            }
            connect(with: selectServerClosure)
        }
    }
    
    public func quickConnect() {
        siriHelper?.donateQuickConnect()
        lastConnectionType = .quick
        
        let propertiesManager = PropertiesManager()
        if let quickConnectProfileId = propertiesManager.quickConnect, let profile = profileManager.profile(withId: quickConnectProfileId) {
            connectTo(profile: profile)
        } else {
            let connectionRequest = ConnectionRequest(serverType: activeServerType, connectionType: .fastest)
            propertiesManager.lastConnectionRequest = connectionRequest
            
            let selectServerClosure: ([SessionModel]?) -> (ServerModel?) = { [weak self] sessions in
                guard let `self` = self else { return nil }
                return self.selectServer(connectionRequest: connectionRequest, sessions: sessions)
            }
            connect(with: selectServerClosure)
        }
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        lastConnectionType = .country(code: countryCode, type: serverType)
        
        let connectionRequest = ConnectionRequest(serverType: activeServerType, connectionType: .country(countryCode, .fastest))
        propertiesManager.lastConnectionRequest = connectionRequest
        
        let selectServerClosure: ([SessionModel]?) -> (ServerModel?) = { [weak self] sessions in
            guard let `self` = self else { return nil }
            return self.selectServer(connectionRequest: connectionRequest, sessions: sessions)
        }
        connect(with: selectServerClosure)
    }
    
    public func connectTo(server: ServerModel) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: activeServerType, connectionType: .country(server.countryCode, countryType))
        propertiesManager.lastConnectionRequest = connectionRequest
        
        lastConnectionType = .server(server)
        
        let selectServerClosure: ([SessionModel]?) -> (ServerModel?) = { _ in
            return server
        }
        if let requiresUpgrade = serverTierChecker.serverRequiresUpgrade(server), !requiresUpgrade {
            connect(with: selectServerClosure)
        }
    }
    
    public func connectTo(profile: Profile) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        lastConnectionType = .profile(profile)
        propertiesManager.lastConnectionRequest = profile.connectionRequest
        
        let selectServerClosure: ([SessionModel]?) -> (ServerModel?)
        switch profile.serverOffering {
        case .fastest, .random:
            selectServerClosure = { [weak self] sessions in
                guard let `self` = self else { return nil }
                return self.selectServer(connectionRequest: profile.connectionRequest, sessions: sessions)
            }
        case .custom(let sWrapper):
            selectServerClosure = { [weak self] _ in
                guard let `self` = self else { return nil }
                if let requiresUpgrade = self.serverTierChecker.serverRequiresUpgrade(sWrapper.server), !requiresUpgrade {
                    self.changeActiveServerType(sWrapper.server.serverType)
                    return sWrapper.server
                } else {
                    return nil
                }
            }
        }
        
        connect(with: selectServerClosure)
    }
    
    public func retryConnection() {
        if let connectionType = lastConnectionType {
            switch connectionType {
            case .auto:
                autoConnect()
            case .quick:
                quickConnect()
            case .country(code: let code, type: let type):
                connectTo(country: code, ofType: type)
            case .server(let server):
                connectTo(server: server)
            case .profile(let profile):
                connectTo(profile: profile)
            }
        } else {
            PMLog.D("Connection retry requested")
            let selectServerClosure: ([SessionModel]?) -> (ServerModel?) = { [weak self] _ in
                return self?.activeServer
            }
            connect(with: selectServerClosure)
        }
    }
    
    public func stopConnecting(userInitiated: Bool) {
        PMLog.D("Connecting cancled, userInitiated: \(userInitiated)")
        connectionPreparer?.cancelPreparingConnection()
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
    private func filter(servers: [ServerModel], forSpecificCountry: Bool, type: ServerType, sessions: [SessionModel]?) -> [ServerModel] {
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
            
            guard let sessions = sessions else {
                return serversWithoutMaintenance
            }
            
            let serversWithoutExistingSession = serversWithoutMaintenance.filter { server in
                let availableServerIps = server.ips.filter { ip in
                    return !sessions.contains { session in
                        session.vpnProtocol == .ikev2 && ip.exitIp == session.exitIp
                    }
                }
                return !availableServerIps.isEmpty
            }
            if serversWithoutExistingSession.isEmpty {
                notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: .existingConnection)
                let error = ApplicationError.existingSession
                PMLog.ET(error.localizedDescription)
                return []
            }
            
            return serversWithoutExistingSession
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
    
    private func selectServer(connectionRequest: ConnectionRequest, sessions: [SessionModel]?) -> ServerModel? {
        // use the ui to determine connection type if unspecified
        let type = connectionRequest.serverType == .unspecified ? activeServerType : connectionRequest.serverType
        
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
            
        let servers = filter(servers: sortedServers, forSpecificCountry: forSpecificCountry, type: type, sessions: sessions)
        
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
            switch appStateManager.state {
            case .connecting:
                return nil
            default:
                return pickServer(from: filtered, connectionRequest: connectionRequest)
            }
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
            default:
                return nil
            }
        }
    }
    
    private func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        stopConnecting(userInitiated: false)
        serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
    }
    
    private func connect(with selectServerClosure: @escaping ([SessionModel]?) -> (ServerModel?)) {
        connectionPreparer?.cancelPreparingConnection()
        
        guard selectServerClosure(nil) != nil else {
            return
        }
        
        appStateManager.prepareToConnect()
        
        connectionPreparer = VpnConnectionPreparer(appStateManager: appStateManager, vpnApiService: vpnApiService, alertService: alertService, serverTierChecker: serverTierChecker, vpnKeychain: vpnKeychain)
        connectionPreparer?.prepareConnection(selectServerClosure: selectServerClosure)
    }
    
    @objc private func appStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.connectionChanged, object: self.connection)
        }
    }
}
