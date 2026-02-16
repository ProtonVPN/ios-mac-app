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
import Persistence
import Strings
import SwiftUI
import VPNAppCore
import ConnectionInventory
import CountriesShared

@Reducer
public struct CityStateListFeature: Sendable {

    @ObservableState
    public struct State: Identifiable {
        public var id: String { countryCode }

        @Presents var serversList: ServersListFeature.State?
        let countryCode: String
        let groupInfo: ServerGroupInfo
        let listType: CityStateListType
        var isExpanded: Bool = false


        public init(countryCode: String, groupInfo: ServerGroupInfo, listType: CityStateListType) {
            self.countryCode = countryCode
            self.groupInfo = groupInfo
            self.listType = listType
        }

        public init(listType: CityStateListType, countryCode: String, groupInfo: ServerGroupInfo) {
            self.listType = listType
            self.countryCode = countryCode
            self.groupInfo = groupInfo
        }
    }

    public enum Action {
        case expand
        case serversList(PresentationAction<ServersListFeature.Action>)
        case navigateToServers(ServerGroupInfo)
        case connect(location: ConnectionSpec.Location, trigger: UserInitiatedVPNChange.VPNTrigger?)
        case connectTo(ServerGroupInfo)
        case connectToCountry
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .expand:
                state.isExpanded.toggle()
                return .none
            case let .navigateToServers(groupInfo):
                switch groupInfo.kind {
                case let .city(name, code):
                    state.serversList = .init(countryCode: code, listType: .city(name))
                case let .state(name, code):
                    state.serversList = .init(countryCode: code, listType: .state(name))
                default:
                    break
                }
                return .none
            case .connectToCountry:
                return .send(.connect(location: state.groupInfo.kind.locationWithOrder(), trigger: nil))
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
            case let .serversList(.presented(.connect(serverInfo: server))):
                let location: ConnectionSpec.Location = .exact(
                    .paid,
                    logicalID: server.logical.id,
                    number: server.logical.serverNameComponents.sequence,
                    subregion: server.logical.state ?? server.logical.city, // state or city name
                    regionCode: state.countryCode
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

private extension CityStateListType {
    var telemetryTrigger: UserInitiatedVPNChange.VPNTrigger {
        switch self {
        case .cities: .countriesCity
        case .states: .countriesState
        }
    }
}
