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

    static var connectionChanged: Notification.Name { get }
    static var activeServerTypeChanged: Notification.Name { get }
    static var needsReconnectNotification: Notification.Name { get }
    
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
    func reconnect(with connectionProtocol: ConnectionProtocol)
    func reconnect(with natType: NATType)
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
    private let profileManager: ProfileManager
    private let serverTierChecker: ServerTierChecker
    private let vpnKeychain: VpnKeychainProtocol
    
    private let serverStorage: ServerStorage = ServerStorageConcrete()
    private let propertiesManager: PropertiesManagerProtocol
    
    private let siriHelper: SiriHelperProtocol?
    
    private var tier: Int {
        return (try? userTier()) ?? CoreAppConstants.VpnTiers.free
    }

    private var serverManager: ServerManager {
        return ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
    }
   
    private var serverTypeToggle: ServerType {
        return propertiesManager.secureCoreToggle ? .secureCore : .standard
    }

    private var globalConnectionProtocol: ConnectionProtocol {
        if propertiesManager.smartProtocol {
            return .smartProtocol
        }

        return .vpnProtocol(propertiesManager.vpnProtocol)
    }
    
    private var connectionPreparer: VpnConnectionPreparer?
    
    public static let connectionChanged = Notification.Name("VpnGatewayConnectionChanged")
    public static let activeServerTypeChanged = Notification.Name("VpnGatewayActiveServerTypeChanged")
    public static let needsReconnectNotification = Notification.Name("VpnManagerNeedsReconnect")
    
    public weak var alertService: CoreAlertService? {
        didSet {
            serverTierChecker.alertService = alertService
        }
    }
    
    public var connection: ConnectionStatus
    
    public var lastConnectionRequest: ConnectionRequest? {
        return propertiesManager.lastConnectionRequest
    }
    
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private var netShieldType: NetShieldType {
        return netShieldPropertyProvider.netShieldType
    }

    private let natTypePropertyProvider: NATTypePropertyProvider
    private var natType: NATType {
        return natTypePropertyProvider.natType
    }

    private let safeModePropertyProvider: SafeModePropertyProvider
    private var safeMode: Bool {
        return safeModePropertyProvider.safeMode
    }
    
    // FUTUREDO: Use factory
    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, siriHelper: SiriHelperProtocol? = nil, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, propertiesManager: PropertiesManagerProtocol, profileManager: ProfileManager) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.siriHelper = siriHelper
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.propertiesManager = propertiesManager
        self.profileManager = profileManager
        serverTierChecker = ServerTierChecker(alertService: alertService, vpnKeychain: vpnKeychain)

        let state = appStateManager.state
        self.connection = ConnectionStatus.forAppState(state)

        if case .connected = state, let activeServer = appStateManager.activeConnection()?.server {
            changeActiveServerType(activeServer.serverType)
        }

        NotificationCenter.default.addObserver(forName: appStateManager.stateChange,
                                               object: nil,
                                               queue: nil,
                                               using: appStateChanged)
        NotificationCenter.default.addObserver(forName: type(of: vpnKeychain).vpnPlanChanged,
                                               object: nil,
                                               queue: nil,
                                               using: userPlanChanged)
        NotificationCenter.default.addObserver(forName: type(of: vpnKeychain).vpnUserDelinquent,
                                               object: nil,
                                               queue: nil,
                                               using: userBecameDelinquent)
        NotificationCenter.default.addObserver(forName: Self.needsReconnectNotification,
                                               object: nil,
                                               queue: nil,
                                               using: reconnectOnNotification)
    }
    
    public func userTier() throws -> Int {
        let tier = try vpnKeychain.fetchCached().maxTier
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
            return profile.connectionRequest(withDefaultNetshield: netShieldType, withDefaultNATType: natType, withDefaultSafeMode: safeMode)
        } else {
            return ConnectionRequest(serverType: serverTypeToggle, connectionType: .fastest, connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil)
        }
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(countryCode, .fastest), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(server: ServerModel) {
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(server.countryCode, countryType), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(profile: Profile) {
        connect(with: profile.connectionRequest(withDefaultNetshield: netShieldType, withDefaultNATType: natType, withDefaultSafeMode: safeMode))
    }
    
    public func retryConnection() {
        connect(with: lastConnectionRequest)
    }
    
    public func reconnect(with netShieldType: NetShieldType) {
        connect(with: lastConnectionRequest?.withChanged(netShieldType: netShieldType))
    }

    public func reconnect(with natType: NATType) {
        connect(with: lastConnectionRequest?.withChanged(natType: natType))
    }

    public func reconnect(with safeMode: Bool) {
        connect(with: lastConnectionRequest?.withChanged(safeMode: safeMode))
    }
    
    public func reconnect(with connectionProtocol: ConnectionProtocol) {
        disconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(CoreAppConstants.protocolChangeDelay), execute: { // Delay enhances reconnection success rate
                self.connect(with: self.lastConnectionRequest?.withChanged(connectionProtocol: connectionProtocol))
            })
        }
    }
    
    public func connect(with request: ConnectionRequest?) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        propertiesManager.lastConnectionRequest = request
        
        guard let request = request else {
            connect(with: globalConnectionProtocol, server: appStateManager.activeConnection()?.server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
            return
        }
        
        connect(with: request.connectionProtocol, server: selectServer(connectionRequest: request), netShieldType: request.netShieldType, natType: natType, safeMode: safeMode)
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
            
            let selected = selector.selectServer(connectionRequest: connectionRequest)
            log.debug("Server selected: \(selected?.logDescription ?? "-")", category: .connectionConnect)
            return selected
            
        } catch {
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
    
    public func stopConnecting(userInitiated: Bool) {
        log.info("Connecting cancelled, userInitiated: \(userInitiated)", category: .connectionConnect)
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
            
            self.vpnApiService.refreshServerInfoIfIpChanged(lastKnownIp: self.propertiesManager.userIp) { [weak self] result in
                guard let self = self else {
                    return
                }

                switch result {
                case let .success(properties):
                    self.propertiesManager.userIp = properties.ip
                    self.serverStorage.store(properties.serverModels)
                    self.profileManager.refreshProfiles()
                case .failure:
                    // Ignore failures as this is a non-critical call
                    break
                }
            }
        }
        
        siriHelper?.donateDisconnect()
        appStateManager.disconnect(completion: completionWrapper)
    }
    
    // MARK: - Private functions
    
    private func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        log.warning("Server resolution unavailable", category: .connectionConnect, metadata: ["forSpecificCountry": "\(forSpecificCountry)", "type": "\(type)", "reason": "\(reason)"])
        stopConnecting(userInitiated: false)
        serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
    }
    
    private func connect(with connectionProtocol: ConnectionProtocol, server: ServerModel?, netShieldType: NetShieldType, natType: NATType, safeMode: Bool) {
        guard let server = server else {
            return
        }
        var smartProtocolConfig = propertiesManager.smartProtocolConfig
        
        // WG + KS is not working on Catalina. Let's prevent users from having troubles.
        #if os(macOS)
        if propertiesManager.killSwitch, #available(macOS 10.15, *) {
            if #available(macOS 11, *) { } else {
                switch connectionProtocol {
                    
                // If WireGuard is selected, let's ask user to change it
                case .vpnProtocol(.wireGuard):
                    log.debug("WireGuard + KillSwitch on Catalina detected. Asking user to change one or another.", category: .connectionConnect, event: .scan)
                    alertService?.push(alert: WireguardKSOnCatalinaAlert(killswiftOffHandler: {
                        self.propertiesManager.killSwitch = false
                        self.connect(with: connectionProtocol, server: server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
                    }, openVpnHandler: {
                        self.connect(with: .vpnProtocol(.openVpn(.tcp)), server: server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
                    }))
                    return
                    
                // If SmartProtocol is used, let's make it smart enough to not select WireGuard if we know it won't work
                case .smartProtocol:
                    log.debug("SmartProtocol + KillSwitch on Catalina detected. Disabling WireGuard in SmartProtocol.", category: .connectionConnect, event: .scan)
                    smartProtocolConfig = smartProtocolConfig.configWithWireGuard(enabled: false)
                    
                default:
                    break
                }
            }
        }
        #endif
        
        propertiesManager.lastPreparedServer = server
        appStateManager.prepareToConnect()
        
        connectionPreparer = VpnConnectionPreparer(appStateManager: appStateManager, vpnApiService: vpnApiService, alertService: alertService, serverTierChecker: serverTierChecker, vpnKeychain: vpnKeychain, smartProtocolConfig: smartProtocolConfig, openVpnConfig: propertiesManager.openVpnConfig, wireguardConfig: propertiesManager.wireguardConfig)

        connectionPreparer?.connect(with: connectionProtocol, to: server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
    }
    
    private func appStateChanged(_ notification: Notification) {
        guard let state = notification.object as? AppState else {
            return
        }

        self.connection = ConnectionStatus.forAppState(state)
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: VpnGateway.connectionChanged,
                                            object: self.connection,
                                            userInfo: [AppState.appStateKey: state])
        }
    }

    private func reconnectOnNotification(_ notification: Notification) {
        connect(with: lastConnectionRequest)
    }
}

fileprivate extension VpnGateway {
    func userPlanChanged( _ notification: Notification ) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }

        if downgradeInfo.to.maxTier < CoreAppConstants.VpnTiers.plus {
            propertiesManager.secureCoreToggle = false
        }
        
        if downgradeInfo.to.maxTier < CoreAppConstants.VpnTiers.basic {
            netShieldPropertyProvider.netShieldType = .off
        }

        if downgradeInfo.to.maxTier < CoreAppConstants.VpnTiers.basic {
            natTypePropertyProvider.natType = .default
        }
        
        guard downgradeInfo.to.maxTier < downgradeInfo.from.maxTier else { return }
        
        var reconnectInfo: VpnReconnectInfo?
        
        if case .connected = connection, let server = appStateManager.activeConnection()?.server, server.tier > downgradeInfo.to.maxTier {
            reconnectInfo = reconnectServer(downgradeInfo, oldServer: server)
        }

        let alert = UserPlanDowngradedAlert(accountUpdate: downgradeInfo, reconnectionInfo: reconnectInfo)
        alertService?.push(alert: alert)
    }
    
    func userBecameDelinquent(_ notification: Notification) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }
        var reconnectInfo: VpnReconnectInfo?
        
        self.disconnect {
            self.vpnApiService.clientCredentials { result in
                switch result {
                case let .success(credentials):
                    self.vpnKeychain.store(vpnCredentials: credentials)
                    if case .connected = self.connection, let server = self.appStateManager.activeConnection()?.server, server.tier > downgradeInfo.to.maxTier {
                        reconnectInfo = self.reconnectServer(downgradeInfo, oldServer: server)
                    }

                    let alert = UserBecameDelinquentAlert(reconnectionInfo: reconnectInfo)
                    self.alertService?.push(alert: alert)
                case let .failure(error):
                    log.error("Error received: \(error)", category: .connectionConnect)
                }
            }
        }
    }
    
    private func reconnectServer( _ downgradeInfo: VpnDowngradeInfo, oldServer: ServerModel? ) -> VpnReconnectInfo? {
        guard let previousServer = oldServer else { return nil }

        let tier = downgradeInfo.to.maxTier
        let serverManager = ServerManagerImplementation.instance(forTier: downgradeInfo.to.maxTier, serverStorage: ServerStorageConcrete())
        let selector = VpnServerSelector(serverType: .unspecified, userTier: tier, serverGrouping: serverManager.grouping(for: serverTypeToggle), appStateGetter: {
            return self.appStateManager.state
        })
        
        let request = ConnectionRequest(
            serverType: serverTypeToggle,
            connectionType: .fastest,
            connectionProtocol: globalConnectionProtocol,
            netShieldType: netShieldPropertyProvider.netShieldType,
            natType: natTypePropertyProvider.natType,
            safeMode: propertiesManager.safeMode,
            profileId: nil)
        
        guard let toServer = selector.selectServer(connectionRequest: request) else { return nil }
        propertiesManager.lastConnectionRequest = request
        self.connect(with: request.connectionProtocol, server: toServer, netShieldType: request.netShieldType, natType: request.natType, safeMode: request.safeMode)
        return (previousServer, toServer)
    }
}
