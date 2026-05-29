//
//  Created on 17.05.23.
//
//  Copyright (c) 2023 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Announcement
import Combine
import ComposableArchitecture
import Connection
import ConnectionDetails
import ConnectionDetailsShared
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import Foundation
import LocalAgent
import ModalsServices
import NetShield
import Payments
import ProtonCoreFeatureFlags
import Strings
import VPNAppCore
import VPNNetworking

@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.connectionIntentStorage) private var connectionIntentStorage
    @Dependency(\.pendingDisconnectCompletions) private var pendingDisconnectCompletions
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.alertService) private var alertService
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.networkInterfacePropertiesProvider) private var networkInterfacePropertiesProvider
    #if os(iOS)
        @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp
    #endif

    @SharedReader(.userTier) private var userTier: Int?
    @Shared(.killSwitch) var killSwitch: Bool

    @Reducer
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
        case localAgentNotice(LocalAgentNoticeFeature)
        case freeConnectionsInfo(FreeConnectionInfoFeature)
        case defaultConnection(DefaultConnectionFeature)
        case whatsNew(WhatsNewPresenterFeature)
        case payments(PaymentsMainFeature)
    }

    @ObservableState
    public struct State: Equatable {
        /// For simplicity's sake, let's implement Connection as a child feature of Home.
        /// In the future, when we add a sibling feature (like countries, settings or profiles),
        /// we will have to have a parent App feature.  Connection can be moved
        public var connection: ConnectionFeature.State
        public var map: HomeMapFeature.State
        public var recents: RecentsFeature.State
        public var connectionCard: HomeConnectionCardFeature.State
        package var sharedProperties: SharedPropertiesFeature.State
        package var connectionStatus: ConnectionStatusFeature.State
        package var announcementBanner: AnnouncementBannerFeature.State
        package var whatsNewChecker: WhatsNewCheckerFeature.State
        package var localAgentNotice: LocalAgentNoticeFeature.State

        fileprivate var shouldPushAlert: Bool = false

        @SharedReader(.connectionState) public var connectionState: ConnectionState
        /// Widget-only shadow of `connectionState`. The widget extension cannot read
        /// `connectionState` (in-memory, process-local), so we keep a file-backed projection
        /// in App Group storage and write it from `connection.delegate.stateChanged`.
        /// **In-process callers must read `connectionState` directly, not this.**
        // TODO: VPNAPPL-3545
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.HomeAlert>?

        public init() {
            self.connectionStatus = .init()
            self.connectionCard = .init()
            self.sharedProperties = .init()
            self.recents = .init()
            self.map = .init()
            self.connection = .initialState
            self.announcementBanner = .noBanner
            self.whatsNewChecker = .init()
            self.localAgentNotice = .init()
        }
    }

    private enum CancelID {
        case connectionState
        case connectionCommands
        case connectionConnectCommandEffect
    }

    public enum Action {
        /// This must be called once
        case onStart

        case changeServer
        case didDismissChangeServer

        /// Forwarded from the `ConnectionCommandClient` stream. Single chokepoint that
        /// translates a `ConnectionCommand` into `ConnectionFeature.input(...)`.
        case connectionCommandReceived(ConnectionCommand)

        case incomingAlert(Alert)
        case killSwitchSettingChanged(Bool)

        case connection(ConnectionFeature.Action)
        case map(HomeMapFeature.Action)
        case recents(RecentsFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        case connectionCard(HomeConnectionCardFeature.Action)
        case sharedProperties(SharedPropertiesFeature.Action)
        case connectionDetails(ConnectionScreenFeature.Action)
        case freeConnectionsInfo(FreeConnectionInfoFeature.Action)
        case announcementBanner(AnnouncementBannerFeature.Action)

        case whatsNewChecker(WhatsNewCheckerFeature.Action)
        case whatsNewPresenter(WhatsNewPresenterFeature.Action)

        case localAgentNotice(LocalAgentNoticeFeature.Action)

        /// Start bug report flow
        case helpButtonPressed

        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<HomeAlert>)

        @CasePathable
        public enum HomeAlert: Equatable {
            /// User chose "Enable Kill Switch" on the bad-LAN alert. We flip the kill switch
            /// (which suppresses the bad-LAN intercept on the re-issued connect) and retry.
            case enableKillSwitchAndConnect(PendingConnect)
            /// User chose "Continue" on the bad-LAN alert. We retry connect bypassing intercepts.
            case connectAnywayDespiteBadLAN(PendingConnect)
        }
    }

    /// Captures the parameters of a `.connect` command paused while we await user input on an
    /// intercept alert.
    public struct PendingConnect: Equatable, Sendable {
        public let spec: ConnectionSpec
        public let connectionProtocol: ConnectionProtocol?
        public let trigger: UserInitiatedVPNChange.VPNTrigger?
    }

    private static let whatsNewPresentationDelay: Duration = .seconds(3)

    public init() {}

    private func allCountriesUpsellModalType() -> UpsellModalType {
        .allCountries(
            numberOfServers: serverRepository.roundedServerCount,
            numberOfCountries: serverRepository.countryCount()
        )
    }

    private func upsellModalType(from bannerType: BannerType) -> UpsellModalType {
        switch bannerType {
        case .worldwideCover:
            allCountriesUpsellModalType()
        case .fasterBrowsing:
            .vpnAccelerator
        case .streaming:
            .streaming
        case .netshield:
            .netShield
        case .secureCore:
            .secureCore
        case .p2p:
            .p2pSupport
        case .devices:
            .devices
        case .tor:
            .torOverVPN
        case .more:
            .customization
        }
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
                ._printChanges()
                .logActions(.connectionLogger) // Logs actions to our usual logger, even outside of DEBUG.
        }
        Scope(state: \.sharedProperties, action: \.sharedProperties) {
            SharedPropertiesFeature()
        }
        Scope(state: \.map, action: \.map) {
            HomeMapFeature()
        }
        Scope(state: \.connectionCard, action: \.connectionCard) {
            HomeConnectionCardFeature()
        }
        Scope(state: \.connectionStatus, action: \.connectionStatus) {
            ConnectionStatusFeature()
        }
        Scope(state: \.recents, action: \.recents) {
            RecentsFeature()
        }
        Scope(state: \.announcementBanner, action: \.announcementBanner) {
            AnnouncementBannerFeature()
        }
        Scope(state: \.whatsNewChecker, action: \.whatsNewChecker) {
            WhatsNewCheckerFeature()
        }
        Scope(state: \.localAgentNotice, action: \.localAgentNotice) {
            LocalAgentNoticeFeature()
        }
        lifecycleAndObservationReducer
        recentsAndSharedPropertiesReducer
        connectionCommandsReducer
        connectionCardReducer
        destinationReducer
        connectionEventsReducer
        miscReducer
            .ifLet(\.$destination, action: \.destination)
            .ifLet(\.$alert, action: \.alert)
    }
}

private extension HomeFeature {
    var lifecycleAndObservationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onStart:
                return .merge(
                    .send(.announcementBanner(.onStart)),
                    .send(.connection(.input(.onLaunch))),
                    .send(.recents(.watchConnectionStatus)),
                    .run { send in
                        await send(.whatsNewChecker(.register))
                        try await clock.sleep(for: Self.whatsNewPresentationDelay)
                        await send(.whatsNewChecker(.check))
                    },
                    .run { send in
                        for await alert in await alertService.alerts() {
                            await send(.incomingAlert(alert))
                        }
                    },
                    .run { [killSwitch = $killSwitch] send in
                        for await value in killSwitch.publisher.removeDuplicates().values.dropFirst() {
                            await send(.killSwitchSettingChanged(value))
                        }
                    },
                    .run { send in
                        let stream = await connectionCommandClient.stream()
                        for await command in stream {
                            await send(.connectionCommandReceived(command))
                        }
                    }
                    .cancellable(id: CancelID.connectionCommands)
                )
                .cancellable(id: CancelID.connectionState)
            case .killSwitchSettingChanged:
                guard state.connectionState.isConnected,
                      let spec = state.connectionState.resolvedIntent?.spec
                else {
                    return .none
                }
                return .send(.connection(.input(.connect(.init(spec: spec, acceptableProtocols: .all)))))
            case let .incomingAlert(alert):
                state.alert = domainAlertState(from: alert)
                return .none
            default:
                return .none
            }
        }
    }

    var recentsAndSharedPropertiesReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .recents(.delegate(.connect(spec, pinned))):
                let trigger: UserInitiatedVPNChange.VPNTrigger = pinned ? .pin : .recent
                connectionCommandClient.send(.connect(spec, nil, trigger))
                return .none
            case let .recents(.delegate(.upsellTapped(type))):
                state.destination = .payments(.init(upsellModalType: upsellModalType(from: type)))
                return .none
            case .sharedProperties(.userLocation(.userLocationFetchFinished(.success(_)))):
                // a bit unfortunate but map.pinOffset can only be updated via this action atm
                return .send(.map(.connectionStateUpdated(state.connectionState)))
            default:
                return .none
            }
        }
    }

    var connectionCommandsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .changeServer:
                guard case .available = authorizer.serverChangeAvailability() else {
                    log.error("User is not authorized for server change, action should have been unavailable")
                    return .none
                }
                // Change Server is a free tier only action
                let spec = ConnectionSpec(location: .any(.random), features: [])
                connectionCommandClient.send(.connect(spec, nil, .changeServer))
                return .none

            case let .connectionCommandReceived(.connect(spec, connectionProtocol, trigger)):
                if trigger == .changeServer {
                    let availability = authorizer.serverChangeAvailability()
                    if case .unavailable = availability {
                        log.error("Connect via .changeServer trigger reached HomeFeature handler while unauthorized")
                        return .none
                    }
                }
                let pending = PendingConnect(spec: spec, connectionProtocol: connectionProtocol, trigger: trigger)
                if let alert = interceptAlert(for: pending) {
                    state.alert = alert
                    return .none
                }
                return performConnect(pending: pending)

            case let .connectionCommandReceived(.disconnect(trigger, completion)):
                let alreadyDisconnected = state.connectionState.is(\.disconnected)
                return .merge(
                    .cancel(id: CancelID.connectionConnectCommandEffect),
                    .run { send in
                        if let completion {
                            if alreadyDisconnected {
                                await MainActor.run { completion() }
                            } else {
                                await pendingDisconnectCompletions.enqueue(completion)
                            }
                        }
                        AppEvent.userInitiatedVPNChange.post(trigger)
                        await send(.connection(.input(.disconnect)))
                    }
                )

            case .connectionCommandReceived(.retry):
                let spec = lastConnectionSpec()
                let intent = ConnectionPreparationIntent(
                    spec: spec,
                    acceptableProtocols: .all
                )
                log.info(
                    "Reconnecting via retry command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.reconnect(connectionProtocol)):
                let spec = lastConnectionSpec()
                let intent = ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol,
                    acceptableProtocols: .all
                )
                log.info(
                    "Reconnecting via reconnect command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.applySettings(settings)):
                return .send(.connection(.input(.applySettings(settings))))

            case let .connectionCommandReceived(.clearConnectionData(completion)):
                return .run { send in
                    await send(.connection(.input(.onLogout)))
                    await completion?()
                }

            case let .alert(.presented(.enableKillSwitchAndConnect(pending))):
                $killSwitch.withLock { $0 = true }
                return performConnect(pending: pending)

            case let .alert(.presented(.connectAnywayDespiteBadLAN(pending))):
                return performConnect(pending: pending)

            case let .connectionStatus(.connectionStatusBanner(.delegate(.upsellTapped(mode)))):
                let upsellModalType: UpsellModalType = switch mode {
                case .netshield:
                    .netShield
                case .serverChange:
                    allCountriesUpsellModalType()
                }
                state.destination = .payments(.init(upsellModalType: upsellModalType))
                return .none

            default:
                return .none
            }
        }
    }

    var connectionCardReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .connectionCard(.delegate(action)):
                switch action {
                case let .connect(spec):
                    connectionCommandClient.send(.connect(spec, nil, .connectionCard))
                    return .none
                case .disconnect:
                    connectionCommandClient.send(.disconnect(.connectionCard))
                    return .none
                case .tapAction:
                    if let detailsState = state.connectionState.connectionScreenFeatureState() {
                        state.destination = .connectionDetails(detailsState)
                    } else if userTier == .freeTier {
                        let freeCountries = Array(Set(
                            serverRepository.getServers(
                                filteredBy: [.tier(.exact(tier: .freeTier))],
                                orderedBy: .nameAscending
                            ).map(\.logical.exitCountryCode)
                        ))

                        state.destination = .freeConnectionsInfo(.init(countryCodes: freeCountries))
                    }
                    return .none
                case .changeServerButtonTapped:
                    let availability = authorizer.serverChangeAvailability()
                    if case .available = availability {
                        return .send(.changeServer)
                    }
                    state.destination = .changeServer(.init(serverChangeAvailability: availability))
                    return .none
                case .defaultConnectionTapped:
                    state.destination = .defaultConnection(.init())
                    return .none
                }
            default:
                return .none
            }
        }
    }

    var destinationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.changeServer(buttonAction))):
                state.destination = nil
                switch buttonAction {
                case .upgradeButtonTapped:
                    state.shouldPushAlert = true
                    return .none
                case .changeServerButtonTapped:
                    return .send(.changeServer)
                }
            case .destination(.presented(.freeConnectionsInfo(.dismissButtonTapped))),
                 .destination(.presented(.defaultConnection(.preferenceSelected))),
                 .destination(.presented(.whatsNew(.dismissItem))):
                state.destination = nil
                return .none
            case .destination(.presented(.freeConnectionsInfo(.upgradeButtonTapped))):
                state.destination = .payments(.init(upsellModalType: allCountriesUpsellModalType()))
                return .none
            case .destination(.presented(.localAgentNotice(.disconnect))):
                state.destination = nil
                connectionCommandClient.send(.disconnect(.fidoAuthentication))
                return .none
            case .destination(.presented(.localAgentNotice(.openFidoAuthentication))):
                return .none
            case .destination(.presented(.payments(.delegate(.completed)))),
                 .destination(.presented(.payments(.delegate(.dismissed)))):
                state.destination = nil
                return .none
            #if os(iOS)
                case .destination(.presented(.payments(.delegate(.createAccountFirstRequested)))):
                    state.destination = nil
                    return .run { @MainActor _ in
                        openCredentiallessSignUp()
                    }
            #endif
            default:
                return .none
            }
        }
    }

    var connectionEventsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .connection(.core(.localAgent(.event(.stats(message))))):
                return .send(.connectionStatus(.newNetShieldStats(message.netShield.toNetShieldModel)))
            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                state.alert = domainAlertState(from: error.alert)
                return .send(.sharedProperties(.connectionFailed(error)))
            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                state.$vpnConnectionStatus.withLock { $0 = connectionState.status }
                return .send(.sharedProperties(.newConnectionState(connectionState)))
            case .connection(.delegate(.disconnected)):
                return .run { _ in
                    await pendingDisconnectCompletions.drainAndInvoke()
                }
            case let .connection(.delegate(.intentResolutionFailed(intent, resolutionError))):
                SentryHelper.shared?.log(error: resolutionError)
                switch resolutionError {
                case .secureCoreUnavailable:
                    state.destination = .payments(.init(upsellModalType: .secureCore))
                    return .none
                case let .specificCountryUnavailable(countryCode):
                    state.destination = .payments(
                        .init(
                            upsellModalType: .country(
                                countryCode: countryCode,
                                numberOfDevices: DomainConstants.maxDeviceCount,
                                numberOfCountries: serverRepository.countryCount()
                            )
                        )
                    )
                    return .none
                case let .serverChangeUnavailable(until, duration, exhaustedSkips):
                    state.destination = .payments(
                        .init(upsellModalType: .cantSkip(
                            before: until,
                            totalDuration: duration,
                            longSkip: exhaustedSkips
                        ))
                    )
                    return .none
                }
            case let .connection(.delegate(.localAgentNotice(authenticationError))):
                state.destination = .localAgentNotice(.init(code: authenticationError.charCode))
                return .none
            default:
                return .none
            }
        }
    }

    var miscReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .whatsNewChecker(.show(items)):
                state.destination = .whatsNew(.init(item: items[0]))
                return .none
            case .didDismissChangeServer:
                if state.shouldPushAlert {
                    state.shouldPushAlert = false
                    state.destination = .payments(.init(upsellModalType: allCountriesUpsellModalType()))
                }
                return .none
            default:
                return .none
            }
        }
    }
}

private extension HomeFeature {
    /// Spec for `.retry` / `.reconnect`. Reads the last resolved intent persisted by
    /// `ConnectionFeature`; falls back to fastest when there's no prior intent.
    func lastConnectionSpec() -> ConnectionSpec {
        (try? connectionIntentStorage.getConnectionIntent().spec) ?? .defaultFastest
    }

    func domainAlertState(from alert: Domain.Alert) -> AlertState<Action.HomeAlert> {
        AlertState {
            TextState(String(localized: alert.title))
        } message: {
            TextState(String(localized: alert.message))
        }
    }

    /// Encapsulates the side effects of dispatching a `.connect` command after intercept checks
    /// have been resolved (either none fired or the user confirmed via alert).
    func performConnect(pending: PendingConnect) -> Effect<Action> {
        let intent = ConnectionPreparationIntent(
            spec: pending.spec,
            connectionProtocol: pending.connectionProtocol,
            acceptableProtocols: .all
        )
        return .run { [trigger = pending.trigger] send in
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
            await send(.connection(.input(.connect(intent))))
        }
        .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
    }

    /// Returns an alert if any pre-connect intercept (e.g. misconfigured LAN) applies to the
    /// pending connect; otherwise `nil`.
    func interceptAlert(for pending: PendingConnect) -> AlertState<Action.HomeAlert>? {
        if propertiesManager.featureFlags.unsafeLanWarnings,
           !killSwitch,
           let bad = networkInterfacePropertiesProvider.firstBadInterface() {
            return AlertState {
                TextState(Localizable.badInterfaceIpRangeAlertTitle)
            } actions: {
                ButtonState(action: .enableKillSwitchAndConnect(pending)) {
                    TextState(Localizable.killSwitchEnable)
                }
                ButtonState(role: .destructive, action: .connectAnywayDespiteBadLAN(pending)) {
                    TextState(Localizable.continue)
                }
            } message: {
                TextState(Localizable.promptKillSwitchDueToBadInterfaceIpRange(
                    bad.name ?? "Unknown Interface",
                    bad.subnetDescription ?? "Unknown Subnet"
                ))
            }
        }
        return nil
    }
}

private extension FeatureStatisticsMessage.NetShieldStats {
    var toNetShieldModel: NetShield.NetShieldModel {
        NetShieldModel(
            trackersCount: trackersBlocked ?? 0,
            adsCount: adsBlocked ?? 0,
            dataSaved: UInt64(bytesSaved),
            enabled: true
        )
    }
}

// MARK: - Destination.State Equatable Conformance

extension HomeFeature.Destination.State: Equatable {}
