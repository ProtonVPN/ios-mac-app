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

import ConnectionDetails
import Connection
import Domain
import Ergonomics
import ModalsServices
import LocalAgent
import NetShield
import VPNAppCore

import ProtonCoreFeatureFlags

@available(iOS 17, *)
@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.pushAlert) private var pushAlert
    @Dependency(\.date) private var date
    @Dependency(\.alertService) private var alertService

    @SharedReader(.userTier) private var userTier: Int

    @Reducer(state: .equatable)
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
        case freeConnectionsInfo(FreeConnectionInfoFeature)
        case defaultConnection(DefaultConnectionFeature)
    }

    @ObservableState
    public struct State: Equatable {
        /// For simplicity's sake, let's immplement Connection as a child feature of Home.
        /// In the future, when we add a sibling feature (like countries, settings or profiles),
        /// we will have to have a parent App feature.  Connection can be moved
        public var connection: ConnectionFeature.State
        public var map: HomeMapFeature.State
        public var recents: RecentsFeature.State
        public var connectionCard: HomeConnectionCardFeature.State
        package var sharedProperties: SharedPropertiesFeature.State
        package var connectionStatus: ConnectionStatusFeature.State

        @SharedReader(.connectionState)
        var connectionState: ConnectionState?
        @SharedReader(.vpnConnectionStatus)
        public var vpnConnectionStatus: VPNConnectionStatus

        @Presents
        public var destination: Destination.State?

        public init() {
            self.connectionStatus = .init()
            self.connectionCard = .init()
            self.sharedProperties = .init()
            self.recents = .init()
            self.map = .init()
            self.connection = .init()
        }
    }

    private enum CancelID {
        case connectTask
        case connectionState
    }

    @CasePathable
    public enum Action {
        /// This must be called once
        case onStart

        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec)
        case changeServer
        case disconnect

        case incomingAlert(AlertService.Alert)

        case onNewConnectionState(ConnectionState)

        case connection(ConnectionFeature.Action)
        case map(HomeMapFeature.Action)
        case recents(RecentsFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        case connectionCard(HomeConnectionCardFeature.Action)
        case sharedProperties(SharedPropertiesFeature.Action)
        case connectionDetails(ConnectionScreenFeature.Action)
        case freeConnectionsInfo(FreeConnectionInfoFeature.Action)

        /// Start bug report flow
        case helpButtonPressed

        case destination(PresentationAction<Destination.Action>)
    }

    private var shouldUseConnectionFeature: Bool {
        FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.useConnectionFeature) &&
        FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        if shouldUseConnectionFeature {
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
        Reduce { state, action in
            switch action {
            case .onStart:
                return .concatenate(
                    .run { send in await send(.connection(.startObserving)) },
                    .merge(
                        .onChange(of: state.$connectionState, reinject: Action.onNewConnectionState),
                        .run { send in
                            for await alert in await alertService.alerts() {
                                await send(.incomingAlert(alert))
                            }
                        }
                    )
                )
                .cancellable(id: CancelID.connectionState)
            case .recents(.delegate(.connect(let spec))):
                return .send(.connect(spec))
            case .recents:
                return .none
            case .sharedProperties(.userLocation(.userLocationChange(_))):
                // a bit unfortunate but map.pinOffset can only be updated via this action atm
                return .send(.map(.connectionStateUpdated(state.vpnConnectionStatus)))
            case .sharedProperties(_):
                return .none
            case let .connect(spec):
                return .run { send in
                    try await connectToVPN(spec)
                    await send(.recents(.connectionEstablished(spec)))
                } catch: { error, _ in
                    await alertService.feed(error)
                    log.error("Error connecting to VPN: \(error)")
                }
                .cancellable(id: CancelID.connectTask)

            case .changeServer:
                guard case .available = authorizer.serverChangeAvailability() else {
                    log.error("User is not authorized for server change, action should have been unavailable")
                    return .none
                }
                let randomConnectionSpec = ConnectionSpec(location: .random, features: .init())
                return .concatenate([
                    .send(.disconnect),
                    .send(.connect(randomConnectionSpec)),
                ])

            case .disconnect:
                return .run { _ in
                    try await disconnectVPN()
                } catch: { error, _ in
                    await alertService.feed(error)
                    log.error("Error disconnecting from VPN: \(error)")
                }

            case .connectionStatus:
                return .none
            case .connectionDetails:
                return .none
            case .helpButtonPressed:
                return .none
            case .connectionCard(.delegate(let action)):
                switch action {
                case .connect(let spec):
                    return .send(.connect(spec))
                case .disconnect:
                    return .merge(
                        .send(.disconnect),
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
                            ).map { $0.logical.exitCountryCode }
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
            case .destination(.presented(.changeServer(.buttonTapped))):
                state.destination = nil
                if case .available = authorizer.serverChangeAvailability() {
                    return .send(.changeServer)
                }
                return .run { send in
                    @Dependency(\.continuousClock) var clock
                    try await clock.sleep(for: .seconds(1)) // VPNAPPL-2560: give some time for the current presented view to disappear
                    pushAlert(AllCountriesUpsellAlert())
                }
            case .destination(.presented(.freeConnectionsInfo(.dismissButtonTapped))):
                state.destination = nil
                return .none
            case .destination(.presented(.freeConnectionsInfo(.upgradeButtonTapped))):
                return .run { send in
                    @Dependency(\.pushAlert) var pushAlert
                    pushAlert(AllCountriesUpsellAlert())
                }
            case .destination(.presented(.defaultConnection(.preferenceSelected))):
                state.destination = nil
                return .none
            case .destination(_):
                return .none
            case .onNewConnectionState(let newConnectionState):
                log.debug("Connection layer state update \(newConnectionState)")
                do {
                    let newConnectionStatus = try newConnectionState.connectionStatus()
                    return .send(.sharedProperties(.newConnectionStatus(newConnectionStatus)))
                } catch {
                    log.error("Missing original connection intent", category: .connection, metadata: ["error": "\(error)"])
                    return .send(.connection(.disconnect(.connectionFailure(.intentMissing))))
                }
            case .map:
                return .none
            case .freeConnectionsInfo(_):
                return .none
            case .connection(.localAgent(.event(.stats(let message)))):
                return .send(.connectionStatus(.newNetShieldStats(message.netShield.toNetShieldModel)))
            case .connection(_):
                return .none
            case .incomingAlert(let alert):
                pushAlert(alert.toSystemAlert)
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

fileprivate extension AlertService.Alert {
    var toSystemAlert: any SystemAlert {
        let alert = ConnectionPackageErrorAlert()
        alert.title = String(localized: title)
        alert.message = String(localized: message)
        return alert
    }
}

private extension FeatureStatisticsMessage.NetShieldStats {
    var toNetShieldModel: NetShield.NetShieldModel {
        return NetShieldModel(
            trackersCount: trackersBlocked ?? 0,
            adsCount: adsBlocked ?? 0,
            dataSaved: UInt64(bytesSaved),
            enabled: true
        )
    }
}
