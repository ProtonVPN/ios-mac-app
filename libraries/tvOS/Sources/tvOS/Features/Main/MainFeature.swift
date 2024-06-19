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

@Reducer
struct MainFeature {

    enum Tab { case home, settings }

    @ObservableState
    struct State: Equatable {
        var currentTab: Tab = .home
        var homeLoading = HomeLoadingFeature.State.loading
        var settings = SettingsFeature.State()

        var connection = ConnectionFeature.State()

        @Presents var alert: AlertState<Action.Alert>?
        
        @Shared(.inMemory("connectionState")) var connectionState: Connection.ConnectionState?
    }

    enum Action {
        case selectTab(Tab)
        case homeLoading(HomeLoadingFeature.Action)
        case settings(SettingsFeature.Action)

        case onAppear

        case connection(ConnectionFeature.Action)
        
        case alert(PresentationAction<Alert>)

        case connectionStateUpdated(Connection.ConnectionState?)

        @CasePathable
        enum Alert {
          case errorMessage
        }
    }

    static let connectionFailedAlert = AlertState<Action.Alert> {
        TextState("Connection failed")
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
            case .onAppear:
                return .merge(
                    .publisher { state.$connectionState.publisher.receive(on: UIScheduler.shared).map(Action.connectionStateUpdated) },
                    .run { send in
                        await send(.connection(.tunnel(.startObservingStateChanges)))
                        await send(.connection(.localAgent(.startObservingEvents)))
                    }
                )
            case .selectTab(let tab):
                state.currentTab = tab
                return .none
            case .settings:
                return .none

            case .homeLoading(.loaded(.countryList(.selectItem(let item)))):
                guard let (connectServer, features) = serverWithFeatures(code: item.code) else {
                    return .none
                }

                return .send(.connection(.connect(connectServer, features)))

            case .homeLoading(.loaded(.protectionStatus(let action))):
                return .run { send in
                    switch action {
                    case .userClickedDisconnect:
                        await send(.connection(.disconnect(nil)))
                    case .userClickedCancel:
                        await send(.connection(.disconnect(nil)))
                    case .userClickedConnect:
                        guard let (connectServer, features) = serverWithFeatures(code: "Fastest") else {
                            return
                        }
                        // quick connect
                        await send(.connection(.connect(connectServer, features)))
                    default:
                        break
                    }
                }

            case .homeLoading:
                return .none
            case .connectionStateUpdated(let connectionState):
                if case .disconnected(let error) = connectionState, let error {
                    state.alert = Self.connectionFailedAlert
                }
                return .none
            case .connection:
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    func serverWithFeatures(code: String) -> (Server, VPNConnectionFeatures)? {
        @Dependency(\.serverRepository) var repository
        let filters = code == "Fastest" ?  [] : [VPNServerFilter.kind(.country(code: code))]
        let server = repository.getFirstServer(filteredBy: filters, orderedBy: .fastest)!
        guard let endpoint = server.endpoints.first else {
            return nil
        }
        let connectServer = Server(logical: server.logical, endpoint: endpoint)

        let features = VPNConnectionFeatures(netshield: .level1,
                                             vpnAccelerator: true,
                                             bouncing: "1",
                                             natType: .moderateNAT,
                                             safeMode: false)
        return (connectServer, features)
    }
}
