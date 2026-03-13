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

import Combine
import Foundation

import ComposableArchitecture
import Dependencies

import ProtonCoreFeatureFlags

import Announcement
import Connection
import ConnectionDetails
import LocalAgent
import ModalsServices
import NetShield
#if os(iOS)
    import Payments
#endif
import VPNAppCore

import Domain
import Ergonomics

@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.pushAlert) private var pushAlert
    @Dependency(\.alertService) private var alertService
    @Dependency(\.continuousClock) private var clock
    #if os(iOS)
        @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp
    #endif

    @SharedReader(.userTier) private var userTier: Int?

    @Reducer
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
        case localAgentNotice(LocalAgentNoticeFeature)
        case freeConnectionsInfo(FreeConnectionInfoFeature)
        case defaultConnection(DefaultConnectionFeature)
        case whatsNew(WhatsNewPresenterFeature)
        #if os(iOS)
            case payments(PaymentsMainFeature)
        #endif
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

        public init() {
            self.connectionStatus = .init(isUsingConnectionPackage: HomeFeature.shouldUseConnectionFeature)
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
        case connectTask
        case connectionState
    }

    public enum Action {
        /// This must be called once
        case onStart

        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec, UserInitiatedVPNChange.VPNTrigger)
        case changeServer
        case didDismissChangeServer
        case disconnect(UserInitiatedVPNChange.VPNTrigger)

        case incomingAlert(Alert)

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
    }

    private static let shouldUseConnectionFeature: Bool = FeatureFlagsRepository.isConnectionFeatureEnabled

    private static let whatsNewPresentationDelay: Duration = .seconds(3)

    public init() {}

    #if os(iOS)
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
    #endif

    public var body: some Reducer<State, Action> {
        if Self.shouldUseConnectionFeature {
            Scope(state: \.connection, action: \.connection) {
                ConnectionFeature()
                    ._printChanges()
                    .logActions(.connectionLogger) // Logs actions to our usual logger, even outside of DEBUG.
            }
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
        Reduce { state, action in
            switch action {
            case .onStart:
                return .merge(
                    .send(.announcementBanner(.onStart)),
                    .send(.connection(.input(.onLaunch))),
                    .run { send in
                        await send(.whatsNewChecker(.register))
                        try await clock.sleep(for: Self.whatsNewPresentationDelay)
                        await send(.whatsNewChecker(.check))
                    },
                    .run { send in
                        for await alert in await alertService.alerts() {
                            await send(.incomingAlert(alert))
                        }
                    }
                )
                .cancellable(id: CancelID.connectionState)
            case let .recents(.delegate(.connect(spec, pinned))):
                return .send(.connect(spec, pinned ? .pin : .recent))
            case let .recents(.delegate(.upsellTapped(type))):
                #if os(iOS)
                    state.destination = .payments(.init(upsellModalType: upsellModalType(from: type)))
                #else
                    let alert: SystemAlert = switch type {
                    case .worldwideCover:
                        AllCountriesUpsellAlert()
                    case .fasterBrowsing:
                        VPNAcceleratorUpsellAlert()
                    case .streaming:
                        StreamingUpsellAlert()
                    case .netshield:
                        NetShieldUpsellAlert()
                    case .secureCore:
                        SecureCoreUpsellAlert()
                    case .p2p:
                        P2PUpsellAlert()
                    case .devices:
                        DevicesUpsellAlert()
                    case .tor:
                        TorUpsellAlert()
                    case .more:
                        CustomizationUpsellAlert()
                    }
                    pushAlert(alert)
                #endif
                return .none
            case .recents:
                return .none
            case .sharedProperties(.userLocation(.userLocationFetchFinished(.success(_)))):
                // a bit unfortunate but map.pinOffset can only be updated via this action atm
                return .send(.map(.connectionStateUpdated(state.vpnConnectionStatus)))
            case .sharedProperties:
                return .none
            case let .connect(spec, trigger):
                return .run { send in
                    try await connectToVPN(spec, nil, trigger)
                    await send(.recents(.connectionEstablished(spec)))
                } catch: { error, _ in
                    log.error("Error connecting to VPN: \(error)")
                    await alertService.feed(error)
                }
                .cancellable(id: CancelID.connectTask)
            case .changeServer:
                guard case .available = authorizer.serverChangeAvailability() else {
                    log.error("User is not authorized for server change, action should have been unavailable")
                    return .none
                }
                let randomConnectionSpec = ConnectionSpec(location: .any(.random), features: .init())
                return .concatenate([
                    .send(.connect(randomConnectionSpec, .changeServer)),
                ])
            case let .disconnect(trigger):
                return .run { _ in
                    try await disconnectVPN(trigger)
                } catch: { error, _ in
                    log.error("Error disconnecting from VPN: \(error)")
                    await alertService.feed(error)
                }
            case let .connectionStatus(.connectionStatusBanner(.delegate(.upsellTapped(mode)))):
                #if os(iOS)
                    let upsellModalType: UpsellModalType = switch mode {
                    case .netshield:
                        .netShield
                    case .serverChange:
                        allCountriesUpsellModalType()
                    }
                    state.destination = .payments(.init(upsellModalType: upsellModalType))
                #else
                    let alert: SystemAlert = switch mode {
                    case .netshield:
                        NetShieldUpsellAlert()
                    case .serverChange:
                        AllCountriesUpsellAlert()
                    }
                    pushAlert(alert)
                #endif
                return .none
            case .connectionStatus:
                return .none
            case .connectionDetails:
                return .none
            case .helpButtonPressed:
                return .none
            case let .connectionCard(.delegate(action)):
                switch action {
                case let .connect(spec):
                    return .send(.connect(spec, .connectionCard))
                case .disconnect:
                    return .merge(
                        .send(.disconnect(.connectionCard)),
                        .cancel(id: CancelID.connectTask)
                    )
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
            case .connectionCard:
                return .none
            case let .destination(.presented(.changeServer(buttonAction))):
                state.destination = nil
                switch buttonAction {
                case .upgradeButtonTapped:
                    state.shouldPushAlert = true
                    return .none
                case .changeServerButtonTapped:
                    return .send(.changeServer)
                }
            case .destination(.presented(.freeConnectionsInfo(.dismissButtonTapped))):
                state.destination = nil
                return .none
            case .destination(.presented(.freeConnectionsInfo(.upgradeButtonTapped))):
                #if os(iOS)
                    state.destination = .payments(.init(upsellModalType: allCountriesUpsellModalType()))
                #else
                    pushAlert(AllCountriesUpsellAlert())
                #endif
                return .none
            case .destination(.presented(.defaultConnection(.preferenceSelected))):
                state.destination = nil
                return .none
            case .destination(.presented(.whatsNew(.dismissItem))):
                state.destination = nil
                return .none
            case .destination(.presented(.localAgentNotice(.disconnect))):
                state.destination = nil
                return .send(.disconnect(.fidoAuthentication))
            case .destination(.presented(.localAgentNotice(.openFidoAuthentication))):
                return .none
            #if os(iOS)
                case .destination(.presented(.payments(.delegate(.completed)))),
                     .destination(.presented(.payments(.delegate(.dismissed)))):
                    state.destination = nil
                    return .none
                case .destination(.presented(.payments(.delegate(.createAccountFirstRequested)))):
                    state.destination = nil
                    return .run { @MainActor _ in
                        openCredentiallessSignUp()
                    }
            #endif
            case .destination:
                return .none
            case .map:
                return .none
            case .freeConnectionsInfo:
                return .none
            case let .connection(.core(.localAgent(.event(.stats(message))))):
                return .send(.connectionStatus(.newNetShieldStats(message.netShield.toNetShieldModel)))
            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                return .run { _ in await alertService.feed(error) }
            case let .whatsNewChecker(.show(items)):
                state.destination = .whatsNew(.init(item: items[0]))
                return .none
            case .whatsNewChecker(_), .whatsNewPresenter:
                return .none
            case let .incomingAlert(alert):
                pushAlert(DomainErrorAlert(alert: alert))
                return .none
            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                let status = connectionState.status
                return .concatenate(
                    .send(.sharedProperties(.newConnectionState(connectionState))),
                    .send(.sharedProperties(.newConnectionStatus(status)))
                )
            case let .connection(.delegate(.intentResolutionFailed(intent, resolutionError))):
                SentryHelper.shared?.log(error: resolutionError)
                switch resolutionError {
                case .secureCoreUnavailable:
                    #if os(iOS)
                        state.destination = .payments(.init(upsellModalType: .secureCore))
                    #else
                        return .run { [pushAlert] _ in
                            pushAlert(SecureCoreUpsellAlert())
                        }
                    #endif
                    return .none
                case let .specificCountryUnavailable(countryCode):
                    #if os(iOS)
                        state.destination = .payments(
                            .init(
                                upsellModalType: .country(
                                    countryCode: countryCode,
                                    numberOfDevices: DomainConstants.maxDeviceCount,
                                    numberOfCountries: serverRepository.countryCount()
                                )
                            )
                        )
                    #else
                        return .run { [pushAlert] _ in
                            pushAlert(CountryUpsellAlert(countryCode: countryCode))
                        }
                    #endif
                    return .none
                case let .serverChangeUnavailable(until, duration, exhaustedSkips):
                    return .run { [pushAlert] send in
                        let alert: SystemAlert = ConnectionCooldownAlert(until: until, duration: duration, longSkip: exhaustedSkips) {
                            Task { [intent, send] in
                                await send(.connection(.input(.connect(intent))))
                            }
                        }
                        pushAlert(alert)
                    }
                }
            case let .connection(.delegate(.localAgentNotice(authenticationError))):
                state.destination = .localAgentNotice(.init(code: authenticationError.charCode))
                return .none
            case .connection:
                return .none
            case .didDismissChangeServer:
                if state.shouldPushAlert {
                    state.shouldPushAlert = false
                    #if os(iOS)
                        state.destination = .payments(.init(upsellModalType: allCountriesUpsellModalType()))
                    #else
                        return .run { [pushAlert] _ in
                            pushAlert(AllCountriesUpsellAlert())
                        }
                    #endif
                }
                return .none
            case .announcementBanner:
                return .none
            case .localAgentNotice:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
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
