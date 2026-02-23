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
public struct ServersListFeature {
    @ObservableState
    public struct State: Equatable {
        var list: ServersList = .loading
        let kind: ServerGroupInfo.Kind
        let search: String

        public enum ServersList: Equatable {
            case loading
            case loaded([ServerInfo])
        }
    }

    public enum Action {
        case connect(serverInfo: ServerInfo)
        case didAppear
        case loaded([ServerInfo])
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                @SharedReader(.secureCoreToggle) var secureCoreToggle: Bool
                return .run { [kind = state.kind, search = state.search] send in
                    @Dependency(\.serverRepository) var repository
                    let servers = switch kind {
                    case let .city(name, code):
                        repository.getServers(
                            filteredBy: [.kind(.city(name: name, code: code)), .features(secureCoreToggle ? .secureCore : .standard), .matches(search)],
                            orderedBy: .loadAscending
                        )
                    case let .state(name, code):
                        repository.getServers(
                            filteredBy: [.kind(.state(name: name, code: code)), .features(secureCoreToggle ? .secureCore : .standard), .matches(search)],
                            orderedBy: .loadAscending
                        )
                    case let .gateway(name):
                        repository.getServers(
                            filteredBy: [.kind(.gateway(name: name)), .features(secureCoreToggle ? .secureCore : .standard), .matches(search)],
                            orderedBy: .loadAscending
                        )
                    case .country:
                        [ServerInfo]()
                    }
                    await send(.loaded(servers))
                }
            case let .loaded(servers):
                state.list = .loaded(servers)
                return .none
            case .connect:
                return .none // handled by parent
            }
        }
    }
}
