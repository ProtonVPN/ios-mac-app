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

@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.connectionIntentStorage) private var connectionIntentStorage
    @Dependency(\.pendingDisconnectCompletions) private var pendingDisconnectCompletions
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.alertService) private var alertService
    @Dependency(\.continuousClock) private var clock
    #if os(iOS)
        @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp
    #endif

    @SharedReader(.userTier) private var userTier: Int?
    @SharedReader(.killSwitch) var killSwitch

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
        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus

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
        public enum HomeAlert: Equatable {}
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
                    .run { send in
                        for await value in $killSwitch.publisher.removeDuplicates().values.dropFirst() {
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
                guard state.vpnConnectionStatus.isConnected(using: state.connectionState),
                      let spec = state.vpnConnectionStatus.spec
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
                return .send(.map(.connectionStateUpdated(state.vpnConnectionStatus)))
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
                let randomConnectionSpec = ConnectionSpec(location: .any(.random), features: .init())
                connectionCommandClient.send(.connect(randomConnectionSpec, nil, .changeServer))
                return .none

            case let .connectionCommandReceived(.connect(spec, connectionProtocol, trigger)):
                if trigger == .changeServer {
                    let availability = authorizer.serverChangeAvailability()
                    if case .unavailable = availability {
                        log.error("Connect via .changeServer trigger reached HomeFeature handler while unauthorized")
                        return .none
                    }
                }
                let intent = ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol,
                    acceptableProtocols: .all
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)

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
                    if let connectionState = state.vpnConnectionStatus.actual?.connectionScreenFeatureState() {
                        state.destination = .connectionDetails(connectionState)
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
                state.alert = connectionFailureAlert(for: error)
                return .send(.sharedProperties(.connectionFailed(error)))
            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                let status = connectionState.status
                return .concatenate(
                    .send(.sharedProperties(.newConnectionState(connectionState))),
                    .send(.sharedProperties(.newConnectionStatus(status)))
                )
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

    func connectionFailureAlert(for error: ConnectionError) -> AlertState<Action.HomeAlert> {
        switch error {
        case .preparation(.networkUnreachable):
            AlertState {
                TextState(Localizable.notConnectedToTheInternet)
            }
        default:
            domainAlertState(from: error.alert)
        }
    }

    func domainAlertState(from alert: Domain.Alert) -> AlertState<Action.HomeAlert> {
        AlertState {
            TextState(String(localized: alert.title))
        } message: {
            TextState(String(localized: alert.message))
        }
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

extension ConnectionState {
    var status: VPNConnectionStatus {
        switch self {
        case .resolving:
            // While we are in the unknown state, we cannot yet be sure if the tunnel is active or not,
            // So let's not even try to grab the original connection intent in case we are disconnected.
            return .resolving(nil, nil)

        case .disconnected:
            return .disconnected

        case let .connecting(.unresolved(intent)):
            return .connecting(intent.spec, nil)

        case let .connecting(.resolved(intent, server)):
            return .connecting(intent.spec, server)

        case let .disconnecting(intent, server):
            return .disconnecting(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: nil))

        case let .connected(intent, server, date, _):
            let resolvedConnection = VPNConnectionActual(server: server, intent: intent, connectedDate: date)
            return .connected(intent.spec, resolvedConnection)
        }
    }
}

// MARK: - Destination.State Equatable Conformance

extension HomeFeature.Destination.State: Equatable {}
