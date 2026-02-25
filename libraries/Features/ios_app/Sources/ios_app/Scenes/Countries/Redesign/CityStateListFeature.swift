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
    @Binding var selectedCountryCode: String?

    @Reducer
    enum Path {
        case serversList(ServersListFeature)
    }

    @ObservableState
    struct State: Equatable {
        static func == (lhs: CityStateListFeature.State, rhs: CityStateListFeature.State) -> Bool {
            lhs.countryCode == rhs.countryCode &&
                lhs.listState == rhs.listState &&
                lhs.sectionTitle == rhs.sectionTitle &&
                lhs.path.count == rhs.path.count && // comparing the count is good enough for now
                lhs.alert == nil && rhs.alert == nil // only care that both are nil
        }

        var path = StackState<Path.State>()
        @Presents var alert: AlertState<Action.Alert>?
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
        case navigateTo(ServerGroupInfo)
        case serversUnderMaintenance
        case connect(location: ConnectionSpec.Location, trigger: UserInitiatedVPNChange.VPNTrigger?)
        case disconnect
        case select(String)
        case loaded(CityStateListType)

        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            case maintenance
        }
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.disconnectVPN) var disconnectVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .run { [code = state.countryCode] send in
                    let listType = CityStateListType(countryCode: code, search: "")
                    await send(.loaded(listType))
                }
            case let .navigateTo(groupInfo):
                switch groupInfo.kind {
                case let .city(name, code):
                    state.path.append(.serversList(.init(countryCode: code, listType: .city(name))))

                case let .state(name, code):
                    state.path.append(.serversList(.init(countryCode: code, listType: .state(name))))

                default:
                    break
                }
                return .none
            case .serversUnderMaintenance:
                state.alert = .init {
                    if case .loaded(.states) = state.listState {
                        TextState(Localizable.allServersInStateUnderMaintenance)
                    } else {
                        TextState(Localizable.allServersInCityUnderMaintenance)
                    }
                }
                return .none
            case let .loaded(type):
                state.listState = .loaded(type)
                switch type {
                case let .cities(array):
                    state.sectionTitle = Localizable.citiesSectionTitle(array.count)
                case let .states(array):
                    state.sectionTitle = Localizable.statesSectionTitle(array.count)
                case .gateways:
                    break
                case .secureCores:
                    break
                }
                return .none
            case let .select(name):
                if let listType = state.listState.loadedType {
                    switch listType {
                    case .cities:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .city(name))))
                    case .states:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .state(name))))
                    case .gateways:
                        break
                    case .secureCores:
                        break
                    }
                }
                return .none
            case .disconnect:
                return .run { [listState = state.listState] _ in
                    if case let .loaded(listType) = listState {
                        try await disconnectVPN(listType.telemetryTrigger)
                    } else {
                        try await disconnectVPN(.country)
                    }
                } catch: { error, _ in
                    log.error("Failed to disconnect from VPN from \(#file) with error: \(error)")
                }
            case let .connect(location, trigger):
                let spec = ConnectionSpec(location: location, features: [])
                let connectionProtocol = (try? defaultConnectionStorage.getDefaultProtocol()) ?? .smartProtocol
                let listTrigger = if let listType = state.listState.loadedType {
                    listType.telemetryTrigger
                } else {
                    UserInitiatedVPNChange.VPNTrigger.countriesCity
                }

                return .run { _ in
                    selectedCountryCode = nil // dismiss the feature by nilling out the selected country
                    try await connectToVPN(spec, connectionProtocol, trigger ?? listTrigger)
                    await MainActor.run {
                        DependencyContainer.shared.makeConnectionStatusService().presentStatusViewController()
                    }
                } catch: { error, _ in
                    log.error("Failed to connect to VPN from \(#file) with error: \(error)")
                }
            case let .path(.element(_, action: .serversList(.connect(location)))):
                return .send(.connect(location: location, trigger: .countriesServer))
            case .path(.element(_, action: .serversList(.disconnect))):
                return .send(.disconnect)
            case .path:
                return .none
            case .alert:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$alert, action: \.alert)
    }
}
