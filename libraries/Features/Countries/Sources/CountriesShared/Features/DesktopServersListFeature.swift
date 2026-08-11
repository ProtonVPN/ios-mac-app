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

import CommonNetworking
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct DesktopServersListFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public internal(set) var list: ServersList = .loading
        public let kind: ServerGroupInfo.Kind
        public let search: String

        public enum ServersList: Equatable {
            case loading
            case loaded([ServerInfo])
        }

        /// The backend's translated name for this list's city, shown in the header in place of the kind's
        /// canonical name. Server selection keeps using the canonical name.
        public let translatedName: String?

        public init(kind: ServerGroupInfo.Kind, search: String, translatedName: String? = nil) {
            self.kind = kind
            self.search = search
            self.translatedName = translatedName
        }
    }

    public enum Action {
        case connect(serverInfo: ServerInfo)
        case didAppear
        case loaded([ServerInfo])
        case loadsUpdated
    }

    private enum CancelID {
        case appEvents
    }

    @Dependency(\.serverRepository) var repository
    @SharedReader(.secureCoreToggle) var secureCore: Bool

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .merge(
                    fetch(kind: state.kind, search: state.search),
                    observeServerListUpdatedEvent()
                )
            case .loadsUpdated:
                return fetch(kind: state.kind, search: state.search)
            case let .loaded(servers):
                state.list = .loaded(servers)
                return .none
            case .connect:
                return .none // handled by parent
            }
        }
    }

    private func fetch(kind: ServerGroupInfo.Kind, search: String) -> Effect<Action> {
        .run { send in
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
    }

    private func observeServerListUpdatedEvent() -> Effect<Action> {
        .run { send in
            for await _ in NotificationCenter.default.notifications(named: ServerListUpdateNotification.name) {
                await send(.loadsUpdated)
            }
        }
        .cancellable(id: CancelID.appEvents)
    }
}
