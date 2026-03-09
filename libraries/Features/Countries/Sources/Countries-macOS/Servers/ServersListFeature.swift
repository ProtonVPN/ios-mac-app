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
import CountriesShared
import Domain
import Strings

@Reducer
public struct ServersListFeature: Sendable {
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

    @Dependency(\.serverRepository) var repository
    @SharedReader(.secureCoreToggle) var secureCore: Bool

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .run { [kind = state.kind, search = state.search] send in
                    let servers = repository.getServers(
                        filteredBy: [
                            .kind(kind.serverTypeFilter),
                            .features(secureCore ? .secureCore : .standard),
                            .matches(search),
                            ProtocolFilters().supportedProtocolsFilter,
                        ],
                        orderedBy: .loadAscending
                    )
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
