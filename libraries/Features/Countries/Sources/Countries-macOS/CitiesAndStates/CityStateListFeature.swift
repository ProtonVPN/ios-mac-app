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
import ConnectionInventory
import CountriesShared
import Domain
import Persistence
import Strings
import SwiftUI
import VPNAppCore

@Reducer
public struct CityStateListFeature: Sendable {
    @ObservableState
    public struct State: Identifiable {
        public var id: String

        @Presents var serversList: ServersListFeature.State?
        let search: String
        let groupInfo: ServerGroupInfo
        let listType: CityStateListType
        var isExpanded: Bool

        public init(groupInfo: ServerGroupInfo, search: String, expandedCode: String?, secureCore: Bool) {
            self.listType = CityStateListType(groupInfo: groupInfo, search: search, secureCore: secureCore)
            self.groupInfo = groupInfo
            self.search = search

            let id = switch groupInfo.kind {
            case let .city(name, _), let .state(name, _), let .gateway(name):
                name
            case let .country(code):
                code
            }
            self.id = id
            self.isExpanded = expandedCode == id
        }
    }

    public enum Action {
        case expand
        case serversList(PresentationAction<ServersListFeature.Action>)
        case navigateToServers(ServerGroupInfo)
        case connect(location: ConnectionSpec.Location, trigger: UserInitiatedVPNChange.VPNTrigger?)
        case connectTo(ServerGroupInfo)
        case connectToServer(ServerInfo)
        case connectToCountry
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .expand:
                state.isExpanded.toggle()
                return .none
            case let .navigateToServers(groupInfo):
                state.serversList = .init(kind: groupInfo.kind, search: state.search)
                return .none
            case .connectToCountry:
                if case .secureCores = state.listType {
                    if case let .country(code) = state.groupInfo.kind {
                        return .send(.connect(location: .secureCore(.anyHop(to: code, .fastest)), trigger: .countriesCountry))
                    }
                }
                return .send(.connect(location: state.groupInfo.kind.locationWithOrder(), trigger: .countriesCountry))
            case let .connectTo(groupInfo):
                guard !groupInfo.isUnderMaintenance else {
                    return .none
                }
                return .send(.connect(location: groupInfo.kind.locationWithOrder(), trigger: nil))
            case let .connect(location, trigger):
                let spec = ConnectionSpec(location: location, features: [])
                let connectionProtocol = (try? defaultConnectionStorage.getDefaultProtocol()) ?? .smartProtocol
                let listTrigger = state.listType.telemetryTrigger

                return .run { _ in
                    try await connectToVPN(spec, connectionProtocol, trigger ?? listTrigger)
                } catch: { error, _ in
                    log.error("Failed to connect to VPN from \(#file) with error: \(error)")
                }
            case let .serversList(.presented(.connect(server))):
                return .send(.connectToServer(server))
            case let .connectToServer(server):
                if case .secureCore = server.logical.kind {
                    return .send(.connect(
                        location: .secureCore(.hop(
                            to: server.logical.exitCountryCode,
                            via: server.logical.entryCountryCode
                        )),
                        trigger: .countriesServer
                    ))
                }
                let location: ConnectionSpec.Location = .exact(
                    .paid,
                    logicalID: server.logical.id,
                    number: server.logical.serverNameComponents.sequence,
                    subregion: state.groupInfo.kind.name,
                    regionCode: server.logical.exitCountryCode
                )
                return .send(.connect(location: location, trigger: .countriesServer))
            case .serversList:
                return .none
            }
        }
        .ifLet(\.$serversList, action: \.serversList) {
            ServersListFeature()
        }
    }
}
