//
//  Created on 2026-01-13 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Domain
import Strings

@Reducer
struct ServersListFeature {
    @ObservableState
    struct State: Equatable {
        let countryCode: String
        let listType: ListType
        var list: ServersList = .loading

        @Presents var alert: AlertState<Action.Alert>?

        enum ServersList: Equatable {
            case loading
            case loaded([ServerInfo])
        }

        enum ListType: Equatable {
            case city(String)
            case state(String)

            var name: String {
                switch self {
                case let .city(name), let .state(name):
                    name
                }
            }
        }
    }

    enum Action {
        case connect(location: ConnectionSpec.Location)
        case disconnect
        case serversUnderMaintenance
        case didAppear
        case loaded([ServerInfo])

        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert {
            case maintenance
        }
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.disconnectVPN) var disconnectVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    static let maintenanceAlert = AlertState<Action.Alert> {
        TextState(Localizable.serverUnderMaintenance)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert:
                return .none
            case .serversUnderMaintenance:
                state.alert = .init { TextState(Localizable.serverUnderMaintenance) }
                return .none
            case .didAppear:
                return .run { [listType = state.listType, code = state.countryCode] send in
                    @Dependency(\.serverRepository) var repository
                    let servers = switch listType {
                    case let .city(name):
                        repository.getServers(
                            filteredBy: [.kind(.city(name: name, code: code))],
                            orderedBy: .loadAscending
                        )
                    case let .state(name):
                        repository.getServers(
                            filteredBy: [.kind(.state(name: name, code: code))],
                            orderedBy: .loadAscending
                        )
                    }
                    await send(.loaded(servers))
                }
            case let .loaded(servers):
                state.list = .loaded(servers)
                return .none
            case .disconnect, .connect:
                return .none // handled by parent
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
