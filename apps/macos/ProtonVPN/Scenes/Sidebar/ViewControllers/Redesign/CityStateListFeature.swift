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

@Reducer
struct CityStateListFeature {
    @Reducer
    enum Path {
        case serversList(ServersListFeature)
    }

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        let countryCode: String

        var sectionTitle: String?

        var listState: ListState = .loading

        enum ListState: Equatable {
            case loading
            case loaded(CityStateListType)

            var loadedType: CityStateListType? {
                if case let .loaded(listType) = self {
                    listType
                } else {
                    nil
                }
            }
        }
    }

    enum Action {
        case didAppear
        case path(StackAction<Path.State, Path.Action>)
        case navigateToCity(ServerGroupInfo)
        case connect(location: ConnectionSpec.Location, trigger: UserInitiatedVPNChange.VPNTrigger?)
        case connectTo(ServerGroupInfo)
        case select(String)
        case loaded(CityStateListType)
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .run { [code = state.countryCode] send in
                    let listType = CityStateListType(countryCode: code)
                    await send(.loaded(listType))
                }
            case let .navigateToCity(groupInfo):
                switch groupInfo.kind {
                case let .city(name, code):
                    state.path.append(.serversList(.init(countryCode: code, listType: .city(name))))
                case let .state(name, code):
                    state.path.append(.serversList(.init(countryCode: code, listType: .state(name))))
                default:
                    break
                }
                return .none
            case let .loaded(type):
                state.listState = .loaded(type)
                switch type {
                case let .cities(array):
                    state.sectionTitle = Localizable.citiesSectionTitle(array.count)
                case let .states(array):
                    state.sectionTitle = Localizable.statesSectionTitle(array.count)
                }
                return .none
            case let .select(name):
                if let listType = state.listState.loadedType {
                    switch listType {
                    case .cities:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .city(name))))
                    case .states:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .state(name))))
                    }
                }
                return .none
            case let .connectTo(groupInfo):
                guard !groupInfo.isUnderMaintenance else {
                    return .none
                }
                return .send(.connect(location: groupInfo.kind.locationWithOrder(), trigger: nil))
            case let .connect(location, trigger):
                let spec = ConnectionSpec(location: location, features: [])
                let connectionProtocol = (try? defaultConnectionStorage.getDefaultProtocol()) ?? .smartProtocol
                let listTrigger = state.listState.loadedType?.telemetryTrigger ?? .countriesCity

                return .run { _ in
                    try await connectToVPN(spec, connectionProtocol, trigger ?? listTrigger)
                } catch: { error, _ in
                    log.error("Failed to connect to VPN from \(#file) with error: \(error)")
                }
            case let .path(.element(_, action: .serversList(.connect(server)))):
                let location: ConnectionSpec.Location = .exact(
                    .paid,
                    logicalID: server.logical.id,
                    number: server.logical.serverNameComponents.sequence,
                    subregion: server.logical.state ?? server.logical.city, // state or city name
                    regionCode: state.countryCode
                )
                return .send(.connect(location: location, trigger: .countriesServer))
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
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
