//
//  VpnGateway.swift
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

import Foundation

import Dependencies

import Domain
import VPNShared
import VPNAppCore

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

public enum ResolutionUnavailableReason: Equatable {
    case upgrade(Int)
    case maintenance
    case protocolNotSupported
}

public enum RestrictedServerGroup {
    
    case all
    case country(code: String)
}

public enum ServerSelection {
    
    case fastest
    case random
}

public protocol VpnGatewayProtocol: AnyObject {
    
    var connection: ConnectionStatus { get }
    var lastConnectionRequest: ConnectionRequest? { get }

    static var connectionChanged: Notification.Name { get }
    static var activeServerTypeChanged: Notification.Name { get }
    static var needsReconnectNotification: Notification.Name { get }
    
    func userTier() throws -> Int
    func changeActiveServerType(_ serverType: ServerType)
    func autoConnect()
    func quickConnect(trigger: ConnectionDimensions.VPNTrigger)
    func quickConnectConnectionRequest(trigger: ConnectionDimensions.VPNTrigger) -> ConnectionRequest
    func connectTo(country countryCode: String, ofType serverType: ServerType, trigger: ConnectionDimensions.VPNTrigger)
    func connectTo(country countryCode: String, city: String)
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
    func postConnectionInformation()
}

public protocol VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol
}

public class VpnGateway: VpnGatewayProtocol {
    @Dependency(\.profileAuthorizer) var profileAuthorizer
    @Dependency(\.serverRepository) var repository

    private let vpnApiService: VpnApiService
    private let appStateManager: AppStateManager
    private let profileManager: ProfileManager
    private let serverTierChecker: ServerTierChecker
    private let vpnKeychain: VpnKeychainProtocol
    private let authKeychain: AuthKeychainHandle
    private let availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory
    
    private let propertiesManager: PropertiesManagerProtocol

    private let siriHelper: SiriHelperProtocol?
    
    private var tier: Int {
        return (try? userTier()) ?? .freeTier
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
    private var safeMode: Bool? {
        return safeModePropertyProvider.safeMode
    }

    private let connectionIntercepts: [VpnConnectionInterceptPolicyItem]

    var notificationCenter: NotificationCenter = .default

    public typealias Factory = VpnApiServiceFactory &
        AppStateManagerFactory &
        CoreAlertServiceFactory &
        VpnKeychainFactory &
        AuthKeychainHandleFactory &
        SiriHelperFactory &
        NetShieldPropertyProviderFactory &
        NATTypePropertyProviderFactory &
        SafeModePropertyProviderFactory &
        PropertiesManagerFactory &
        ProfileManagerFactory &
        AvailabilityCheckerResolverFactory &
        VpnConnectionInterceptDelegate

    public convenience init(_ factory: Factory) {
        self.init(
            vpnApiService: factory.makeVpnApiService(),
            appStateManager: factory.makeAppStateManager(),
            alertService: factory.makeCoreAlertService(),
            vpnKeychain: factory.makeVpnKeychain(),
            authKeychain: factory.makeAuthKeychainHandle(),
            siriHelper: factory.makeSiriHelper(),
            netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(),
            natTypePropertyProvider: factory.makeNATTypePropertyProvider(),
            safeModePropertyProvider: factory.makeSafeModePropertyProvider(),
            propertiesManager: factory.makePropertiesManager(),
            profileManager: factory.makeProfileManager(),
            availabilityCheckerResolverFactory: factory,
            connectionIntercepts: factory.vpnConnectionInterceptPolicies
        )
    }

    public init(
        vpnApiService: VpnApiService,
        appStateManager: AppStateManager,
        alertService: CoreAlertService,
        vpnKeychain: VpnKeychainProtocol,
        authKeychain: AuthKeychainHandle,
        siriHelper: SiriHelperProtocol? = nil,
        netShieldPropertyProvider: NetShieldPropertyProvider,
        natTypePropertyProvider: NATTypePropertyProvider,
        safeModePropertyProvider: SafeModePropertyProvider,
        propertiesManager: PropertiesManagerProtocol,
        profileManager: ProfileManager,
        availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory,
        connectionIntercepts: [VpnConnectionInterceptPolicyItem] = []
    ) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.authKeychain = authKeychain
        self.siriHelper = siriHelper
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.propertiesManager = propertiesManager
        self.profileManager = profileManager
        self.availabilityCheckerResolverFactory = availabilityCheckerResolverFactory
        self.connectionIntercepts = connectionIntercepts

        serverTierChecker = ServerTierChecker(alertService: alertService, vpnKeychain: vpnKeychain)

        let state = appStateManager.state
        self.connection = ConnectionStatus.forAppState(state)
        /// Sometimes when launching the app, the `AppStateManager` will post `.AppStateManager.stateChange` notification
        /// before `VPNGateway` has a chance of registering for that notification. For this event we're posting it here.
        postConnectionInformation()

        if case .connected = state, let activeServer = appStateManager.activeConnection()?.server {
            changeActiveServerType(activeServer.serverType)
        }

        notificationCenter.addObserver(
            self,
            selector: #selector(appStateChanged),
            name: .AppStateManager.stateChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(userPlanChanged),
            name: type(of: vpnKeychain).vpnPlanChanged,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(userBecameDelinquent),
            name: type(of: vpnKeychain).vpnUserDelinquent,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reconnectOnNotification),
            name: Self.needsReconnectNotification,
            object: nil
        )
    }
    
    public func userTier() throws -> Int {
        return try vpnKeychain.fetchCached().maxTier
    }
    
    public func changeActiveServerType(_ serverType: ServerType) {
        guard serverTypeToggle != serverType else { return }
        
        propertiesManager.secureCoreToggle = serverType == .secureCore
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            notificationCenter.post(
                name: VpnGateway.activeServerTypeChanged,
                object: self.connection
            )
        }
    }
    
    public func autoConnect() {
        appStateManager.isOnDemandEnabled { [weak self] enabled in
            guard let self = self, !enabled else {
                return
            }

            guard let profile = self.profileManager.autoConnectProfile else {
                self.quickConnect(trigger: .auto)
                return
            }

            // Check whether the user is allowed to use profiles at all
            guard profileAuthorizer.canUseProfiles else {
                // If we're not allowed to use profiles, fallback to fastest. We don't want to upsell here
                self.quickConnect(trigger: .auto)
                return
            }

            // If the tier of the profile is too high, connection will be interrupted later by ServerTierChecker
            self.connectTo(profile: profile)
        }
    }
    
    public func quickConnect(trigger: ConnectionDimensions.VPNTrigger) {
        connect(with: quickConnectConnectionRequest(trigger: trigger))
    }
    
    public func quickConnectConnectionRequest(trigger: ConnectionDimensions.VPNTrigger) -> ConnectionRequest {
        let defaultQCConnectionRequest = ConnectionRequest(
            serverType: serverTypeToggle,
            connectionType: .fastest,
            connectionProtocol: globalConnectionProtocol,
            netShieldType: netShieldType,
            natType: natType,
            safeMode: safeMode,
            profileId: nil,
            trigger: trigger
        )

        guard let profile = profileManager.quickConnectProfile else {
            log.info("Using default QC request, user has no QC profile set", category: .connectionConnect)
            return defaultQCConnectionRequest
        }

        guard profileAuthorizer.canUseProfiles else {
            log.info("Using default QC request, user not authorized for profiles", category: .connectionConnect)
            return defaultQCConnectionRequest
        }

        return profile.connectionRequest(
            withDefaultNetshield: netShieldType,
            withDefaultNATType: natType,
            withDefaultSafeMode: safeMode,
            trigger: trigger
        )
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType, trigger: ConnectionDimensions.VPNTrigger = .country) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(countryCode, .fastest), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: trigger)
        
        connect(with: connectionRequest)
    }

    public func connectTo(country countryCode: String, city: String) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .city(country: countryCode, city: city), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: .city)

        connect(with: connectionRequest)
    }
    
    public func connectTo(server: ServerModel) {
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(server.countryCode, countryType), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: .server)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(profile: Profile) {
        if !profile.isDefaultProfile {
            let updatedProfile = profile.withUpdatedConnectionDate()
            profileManager.updateProfile(updatedProfile)
        }

        let connectionRequest = profile.connectionRequest(withDefaultNetshield: netShieldType, withDefaultNATType: natType, withDefaultSafeMode: safeMode, trigger: .profile)
        connect(with: connectionRequest)
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
                let connectionRequest = self.lastConnectionRequest?.withChanged(connectionProtocol: connectionProtocol)
                self.connect(with: connectionRequest)
            })
        }
    }

    public func connect(with request: ConnectionRequest?) {
        let `protocol` = request?.connectionProtocol ?? globalConnectionProtocol

        if `protocol`.isDeprecated && propertiesManager.featureFlags.enforceDeprecatedProtocols {
            showProtocolDeprecatedAlert(request: request)
            return
        }

        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        propertiesManager.lastConnectionRequest = request
        
        guard let request else {
            gatherParametersAndConnect(
                requestId: UUID(),
                with: `protocol`,
                server: appStateManager.activeConnection()?.server,
                netShieldType: netShieldType,
                natType: natType,
                safeMode: safeMode,
                intent: nil
            )
            return
        }

        @Dependency(\.connectionAuthorizer) var authorizer
        switch authorizer.authorize(request: request) {
        case .failure(.specificCountryUnavailable(let countryCode)):
            alertService?.push(alert: CountryUpsellAlert(countryFlag: .flag(countryCode: countryCode)!))
            log.info("User is not authorized to connect to specific countries (\(countryCode))")
            return
        case .failure(let .serverChangeUnavailable(date, duration, longSkip)):
            log.info("Change server requested, but random connection is still on cooldown until \(date)")
            alertService?.push(alert: ConnectionCooldownAlert(
                until: date,
                duration: duration,
                longSkip: longSkip,
                reconnectClosure: { [weak self, request] in
                    self?.connect(with: request)
                }
            ))
            return
        case .success:
            break
        }
        
        gatherParametersAndConnect(
            requestId: request.id,
            with: `protocol`,
            server: selectServer(connectionRequest: request),
            netShieldType: request.netShieldType,
            natType: natType,
            safeMode: safeMode,
            intent: request.connectionType
        )
    }
    
    private func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        do {
            let currentUserTier = try self.userTier() // accessing from the keychain for each server is very expensive
            
            let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType
            
            let selector = VpnServerSelector(serverType: type,
                                             userTier: currentUserTier,
                                             connectionProtocol: connectionRequest.connectionProtocol,
                                             smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                             appStateGetter: { [unowned self] in
                self.appStateManager.state
            })
            selector.changeActiveServerType = { [unowned self] serverType in
                self.changeActiveServerType(serverType)
            }
            selector.notifyResolutionUnavailable = { [unowned self] forSpecificCountry, type, reason in
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
        notificationCenter.post(
            name: .userInitiatedVPNChange,
            object: UserInitiatedVPNChange.abort
        )
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
            
            guard let self = self else {
                return
            }

            let refreshFreeTierInfo = (try? vpnKeychain.fetchCached().maxTier.isFreeTier) ?? false

            self.vpnApiService.refreshServerInfo(
                ifIpHasChangedFrom: self.propertiesManager.userLocation?.ip,
                freeTier: refreshFreeTierInfo
            ) { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case let .success(properties):
                    guard let properties else {
                        // IP has not changed
                        break
                    }

                    if let userLocation = properties.location {
                        self.propertiesManager.userLocation = userLocation
                    }
                    if let services = properties.streamingServices {
                        self.propertiesManager.streamingServices = services.streamingServices
                    }
                    if refreshFreeTierInfo {
                        let updatedServerIDs = properties.serverModels.reduce(into: Set<String>(), { $0.insert($1.id) })
                        let deletedServerCount = repository.delete(serversWithMinTier: .paidTier, withIDsNotIn: updatedServerIDs)
                        log.info("Deleted \(deletedServerCount) stale paid servers", category: .persistence)
                    }
                    repository.upsert(servers: properties.serverModels.map { VPNServer(legacyModel: $0) })
                    NotificationCenter.default.post(ServerListUpdateNotification(data: .servers), object: nil)
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

    // swiftlint:disable function_body_length function_parameter_count
    /// Determine all of the different features we want to use for the connection, and then go on to the next connection step.
    ///
    /// Gathers the connection protocol (including smart protocol details) and kill switch setting. According to these set values and the
    /// configuration of the hardware, the options specified in `VpnConnectionInterceptPolicyItem` may change this configuration fetched
    /// from settings, possibly according to alerts displayed to the user whether they want to proceed with their normal settings.
    private func gatherParametersAndConnect(
        requestId: UUID,
        with connectionProtocol: ConnectionProtocol,
        server: ServerModel?,
        netShieldType: NetShieldType,
        natType: NATType,
        safeMode: Bool?,
        intent: ConnectionRequestType?
    ) {
        guard let server else {
            return
        }

        var connectionProtocol = connectionProtocol
        let killSwitch = propertiesManager.killSwitch

        var smartProtocolConfig = propertiesManager.smartProtocolConfig
        if !propertiesManager.featureFlags.wireGuardTls {
            // Don't try to connect using TCP or TLS if WireGuardTls feature flag is turned off
            smartProtocolConfig = smartProtocolConfig
                .configWithWireGuard(tcpEnabled: false, tlsEnabled: false)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for policy in self.connectionIntercepts {
                guard !self.applyInterceptPolicy(
                    policy: policy,
                    connectionProtocol: &connectionProtocol,
                    smartProtocolConfig: &smartProtocolConfig,
                    killSwitch: killSwitch
                ) else {
                    break
                }
            }

            self.propertiesManager.lastPreparedServer = server
            let availabilityCheckerResolver = self.availabilityCheckerResolverFactory
                .makeAvailabilityCheckerResolver(
                    openVpnConfig: self.propertiesManager.openVpnConfig,
                    wireguardConfig: self.propertiesManager.wireguardConfig
                )

            self.connectionPreparer = VpnConnectionPreparer(
                appStateManager: self.appStateManager,
                serverTierChecker: self.serverTierChecker,
                availabilityCheckerResolver: availabilityCheckerResolver,
                smartProtocolConfig: smartProtocolConfig,
                openVpnConfig: self.propertiesManager.openVpnConfig,
                wireguardConfig: self.propertiesManager.wireguardConfig
            )

            DispatchQueue.main.async {
                self.appStateManager.prepareToConnect()
                self.connectionPreparer?.determineServerParametersAndConnect(
                    requestId: requestId,
                    with: connectionProtocol,
                    to: server,
                    netShieldType: netShieldType,
                    natType: natType,
                    safeMode: safeMode,
                    intent: intent
                )
            }
        }
    }
    // swiftlint:enable function_body_length function_parameter_count

    /// - Returns: Whether or not the given policy changed connection settings.
    private func applyInterceptPolicy(
        policy: VpnConnectionInterceptPolicyItem,
        connectionProtocol: inout ConnectionProtocol,
        smartProtocolConfig: inout SmartProtocolConfig,
        killSwitch: Bool
    ) -> Bool {
        let group = DispatchGroup()
        group.enter()

        var result: VpnConnectionInterceptResult = .allow
        policy.shouldIntercept(connectionProtocol, isKillSwitchOn: killSwitch) { interceptResult in
            result = interceptResult
            group.leave()
        }
        group.wait()

        guard case .intercept(let parameters) = result else {
            return false
        }

        if parameters.smartProtocolWithoutWireGuard {
            smartProtocolConfig = smartProtocolConfig
                .configWithWireGuard(udpEnabled: false, tcpEnabled: false, tlsEnabled: false)
        }
        if parameters.newKillSwitch != killSwitch {
            self.propertiesManager.killSwitch = parameters.newKillSwitch
        }
        if connectionProtocol != parameters.newProtocol {
            connectionProtocol = parameters.newProtocol
        }

        return true
    }

    public func postConnectionInformation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            notificationCenter.post(
                name: VpnGateway.connectionChanged,
                object: self.connection,
                userInfo: [AppState.appStateKey: self.appStateManager.state]
            )
        }
    }
    
    @objc private func appStateChanged(_ notification: Notification) {
        guard let state = notification.object as? AppState else {
            return
        }
        connection = ConnectionStatus.forAppState(state)
        postConnectionInformation()
    }

    @objc private func reconnectOnNotification(_ notification: Notification) {
        connect(with: lastConnectionRequest)
    }
}

fileprivate extension VpnGateway {
    @objc func userPlanChanged(_ notification: Notification) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }
        let (oldTier, newTier) = (downgradeInfo.from.maxTier, downgradeInfo.to.maxTier)

        if newTier.isFreeTier {
            propertiesManager.secureCoreToggle = false
        }

        [netShieldPropertyProvider, natTypePropertyProvider, safeModePropertyProvider]
            .forEach { $0.adjustAfterPlanChange(from: oldTier, to: newTier) }

        // If user is upgrading from a free account, the server list needs to be updated to contain the paid servers.
        // CAREFUL: refresh server info's continuation is asynchronous here.
        if oldTier.isFreeTier && newTier.isPaidTier {
            vpnApiService.refreshServerInfo(freeTier: false) { [weak self] result in
                switch result {
                case .success(let properties):
                    guard let servers = properties?.serverModels else { break }
                    try? self?.repository.upsert(servers: servers.map { VPNServer(legacyModel: $0) })
                    NotificationCenter.default.post(ServerListUpdateNotification(data: .servers), object: nil)
                case .failure(let error):
                    log.error("Encountered error refreshing server list on plan upgrade: \(error)")
                }
            }
        }

        guard newTier < oldTier else { return }
        
        var reconnectInfo: ReconnectInfo?
        
        if case .connected = connection, let server = appStateManager.activeConnection()?.server, server.tier > newTier {
            reconnectInfo = reconnectServer(downgradeInfo, oldServer: server)
        }

        let alert = UserPlanDowngradedAlert(reconnectInfo: reconnectInfo)

        alertService?.push(alert: alert)
    }
    
    @objc func userBecameDelinquent(_ notification: Notification) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }

        var oldServer: ServerModel?
        if case .connected = self.connection,
           let server = self.appStateManager.activeConnection()?.server,
           server.tier > downgradeInfo.to.maxTier {
            oldServer = server
        }

        self.disconnect {
            Task { [oldServer] in
                do {
                    let credentials = try await self.vpnApiService.clientCredentials()
                    
                    self.vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
                    
                    let reconnectInfo = self.reconnectServer(downgradeInfo, oldServer: oldServer)
                    let alert = UserBecameDelinquentAlert(reconnectInfo: reconnectInfo)
                    self.alertService?.push(alert: alert)
                } catch {
                    log.error("Error received: \(error)", category: .connectionConnect)
                }
            }
        }
    }
    
    private func reconnectServer( _ downgradeInfo: VpnDowngradeInfo, oldServer: ServerModel? ) -> ReconnectInfo? {
        guard let previousServer = oldServer else { return nil }

        let tier = downgradeInfo.to.maxTier
        // Beware: selector selects only non-restricted servers atm. This works now, because
        // if users plan is downgraded, he won't have restricted servers anymore (VPNAPPL-1841)
        let selector = VpnServerSelector(serverType: .unspecified,
                                         userTier: tier,
                                         connectionProtocol: propertiesManager.connectionProtocol,
                                         smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                         appStateGetter: { [unowned self] in
            self.appStateManager.state
        })
        
        let request = ConnectionRequest(
            serverType: serverTypeToggle,
            connectionType: .fastest,
            connectionProtocol: globalConnectionProtocol,
            netShieldType: netShieldPropertyProvider.netShieldType,
            natType: natTypePropertyProvider.natType,
            safeMode: safeModePropertyProvider.safeMode,
            profileId: nil,
            trigger: nil)
        
        guard let toServer = selector.selectServer(connectionRequest: request) else { return nil }
        propertiesManager.lastConnectionRequest = request
        self.gatherParametersAndConnect(
            requestId: request.id,
            with: request.connectionProtocol,
            server: toServer,
            netShieldType: request.netShieldType,
            natType: request.natType,
            safeMode: request.safeMode,
            intent: request.connectionType
        )
        return ReconnectInfo(
            fromServer: .init(name: previousServer.name, image: .flag(countryCode: previousServer.countryCode) ?? Image()),
            toServer: .init(name: toServer.name, image: .flag(countryCode: toServer.exitCountryCode) ?? Image())
        )
    }

    private func showProtocolDeprecatedAlert(request: ConnectionRequest?) {
        let alert = ProtocolDeprecatedAlert(enableSmartProtocolHandler: {
            if self.globalConnectionProtocol.isDeprecated {
                log.info("Global protocol (\(self.globalConnectionProtocol)) is deprecated, updating to smart")
                self.propertiesManager.smartProtocol = true
            }
            guard let profileID = request?.profileId else { return }
            if let profile = self.profileManager.profile(withId: profileID), profile.connectionProtocol.isDeprecated {
                assert(profile.profileType == .user, "System profiles should never use a deprecated protocol")
                log.info("Selected profile (\(profile.id)) uses (\(profile.connectionProtocol), updating to smart")
                self.profileManager.updateProfile(profile.withProtocol(.smartProtocol))
            }
        })
        alertService?.push(alert: alert)
    }
}
