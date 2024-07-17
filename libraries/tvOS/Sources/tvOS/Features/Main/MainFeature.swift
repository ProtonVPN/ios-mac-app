//
//  Created on 25/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture

import struct Domain.VPNConnectionFeatures
import struct Domain.Server
import Connection
import Persistence
import Foundation
import Domain

@Reducer
struct MainFeature {
    enum Tab {
        case home
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var currentTab: Tab = .home
        var homeLoading = HomeLoadingFeature.State.loading
        var settings = SettingsFeature.State()

        var connection = ConnectionFeature.State()

        @SharedReader(.connectionState) var connectionState: ConnectionState?
        @Shared(.userLocation) var userLocation: UserLocation?
        @Shared(.mainBackground) var mainBackground: MainBackground = .clear
    }

    @CasePathable
    enum Action {
        case selectTab(Tab)
        case homeLoading(HomeLoadingFeature.Action)
        case settings(SettingsFeature.Action)

        case onAppear
        case onLogout
        case updateUserLocation

        case connection(ConnectionFeature.Action)

        case errorOccurred(Error)
        
        case connectionStateUpdated(ConnectionState?)
        case observeConnectionState
    }

    private enum CancelId {
        case connectionState
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()._printChanges()
        }
        Scope(state: \.homeLoading, action: \.homeLoading) {
            HomeLoadingFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .connectionStateUpdated(let connectionState):
                if state.currentTab == .home {
                    state.mainBackground = .init(connectionState: connectionState)
                }
                return .none
            case .observeConnectionState:
                return .publisher { state.$connectionState.publisher.receive(on: UIScheduler.shared).map(Action.connectionStateUpdated) }
                    .cancellable(id: CancelId.connectionState)
            case .onAppear:
                return .merge(
                    .send(.observeConnectionState),
                    .send(.connection(.startObserving))
                )
            case .onLogout:
                return .concatenate(
                    .send(.connection(.disconnect(.userIntent))),
                    .send(.connection(.handleLogout)),
                    .send(.connection(.stopObserving))
                )

            case .selectTab(let tab):
                state.currentTab = tab
                switch tab {
                case .home:
                    state.mainBackground = .init(connectionState: state.connectionState)
                    return .none
                case .settings:
                    return .send(.settings(.tabSelected))
                }
            case .settings:
                return .none

            case .homeLoading(.loaded(.countryList(.selectItem(let item)))):
                func effect(_ server: Server?) -> Effect<Action> { // when connecting/connected to a country
                    if let server, server.logical.exitCountryCode == item.code { // and the selected server is the same as the connecting/connected one
                        return .send(.connection(.disconnect(.userIntent))) // just disconnect
                    } else { // and the selected server is different
                        guard let intent = serverConnectionIntent(code: item.code) else { return .none }
                        return .send(.connection(.disconnect(.reconnection(intent)))) // start reconnection, which will first cancel/disconnect current connection
                    }
                }
                // these two below are separate because the server is optional in one and non-optional in the other case
                // which causes the compiler to ignore the non-optional and just send a nil instead
                if case let .connected(server, _) = state.connectionState {
                    return effect(server)
                }
                if case let .connecting(server) = state.connectionState {
                    return effect(server)
                }
                guard let intent = serverConnectionIntent(code: item.code) else { return .none }
                return .send(.connection(.connect(intent)))

            case .homeLoading(.loaded(.protectionStatus(.delegate(let action)))):
                switch action {
                case .userClickedDisconnect:
                    return .send(.connection(.disconnect(.userIntent)))
                case .userClickedCancel:
                    return .send(.connection(.disconnect(.userIntent)))
                case .userClickedConnect:
                    guard let intent = serverConnectionIntent(code: "Fastest") else {
                        return .send(.errorOccurred(ConnectionError.serverMissing))
                    }
                    // quick connect
                    if case .connected = state.connectionState {
                        return .send(.connection(.disconnect(.reconnection(intent))))
                    }
                    return .send(.connection(.connect(intent)))
                }

            case .homeLoading:
                return .none
            case .connection(.disconnect(.connectionFailure(let error))):
                return .merge(
                    .send(.errorOccurred(error)),
                    .send(.updateUserLocation)
                )
            case .connection(.disconnect):
                return .send(.updateUserLocation)
            case .updateUserLocation:
                if state.userLocation == nil {
                    return .run { _ in
                        @Dependency(\.userLocationService) var userLocationService
                        try? await userLocationService.updateUserLocation()
                    }
                }
                return .none
            case .connection:
                if case .disconnected(let error) = state.connectionState, let error {
                    return .send(.errorOccurred(error))
                }
                return .none
            case .errorOccurred(let error):
                return .run { send in
                    @Dependency(\.alertService) var alertService
                    await alertService.feed(error)
                    await send(.connection(.clearErrors))
                }
            }
        }
    }

    func serverConnectionIntent(code: String) -> ServerConnectionIntent? {
        @Dependency(\.serverRepository) var repository
        let filters = code == "Fastest" ?  [] : [VPNServerFilter.kind(.country(code: code))]
        guard let server = repository.getFirstServer(filteredBy: filters, orderedBy: .fastest),
              let endpoint = server.endpoints.first else {
            return nil
        }
        let connectServer = Server(logical: server.logical, endpoint: endpoint)

        return .init(server: connectServer, transport: .udp, features: .defaultTVFeatures)
    }
}
