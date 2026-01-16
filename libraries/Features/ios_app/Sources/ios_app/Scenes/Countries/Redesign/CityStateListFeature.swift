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
        }
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case connect(location: ConnectionSpec.Location)
        case disconnect
        case select(String)
        case didAppear
        case loaded(CityStateListType)
    }

    @Dependency(\.connectToVPN) var connectToVPN
    @Dependency(\.disconnectVPN) var disconnectVPN
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .run { [code = state.countryCode] send in
                    let listType = CityStateListType(countryCode: code)
                    await send(.loaded(listType))
                }
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
                if case let .loaded(listType) = state.listState {
                    switch listType {
                    case .cities:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .city(name))))
                    case .states:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .state(name))))
                    }
                }

                return .none
            case .disconnect:
                return .run { [listState = state.listState] _ in
                    Task {
                        do {
                            if case let .loaded(listType) = listState {
                                try await disconnectVPN(listType.telemetryTrigger)
                            } else {
                                try await disconnectVPN(.country)
                            }
                        } catch {
                            log.error("Failed to disconnect from VPN from \(#file) with error: \(error)")
                        }
                    }
                }
            case let .connect(location):
                let spec = ConnectionSpec(location: location, features: [])
                let connectionProtocol = (try? defaultConnectionStorage.getDefaultProtocol()) ?? .smartProtocol
                return .run { [listState = state.listState] _ in
                    Task {
                        do {
                            if case let .loaded(listType) = listState {
                                try await connectToVPN(spec, connectionProtocol, listType.telemetryTrigger)
                            } else {
                                try await connectToVPN(spec, connectionProtocol, .country)
                            }
                            await MainActor.run {
                                DependencyContainer.shared.makeConnectionStatusService().presentStatusViewController()
                            }
                        } catch {
                            log.error("Failed to connect to VPN from \(#file) with error: \(error)")
                        }
                    }
                }
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
