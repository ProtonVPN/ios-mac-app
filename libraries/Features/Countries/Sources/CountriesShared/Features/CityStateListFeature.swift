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
import VPNAppCore

@Reducer
public struct CityStateListFeature: Sendable {
    @Reducer
    public enum Path {
        case serversList(ServersListFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<Path.State>()
        @Presents public var alert: AlertState<Action.Alert>?
        public let countryCode: String

        public var sectionTitle: String?
        public var listState: ListState = .loading

        public enum ListState: Equatable, Sendable {
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

        public init(countryCode: String) {
            self.countryCode = countryCode
        }
    }

    public enum Action {
        case didAppear
        case path(StackAction<Path.State, Path.Action>)
        case navigateTo(ServerGroupInfo)
        case serversUnderMaintenance
        case connect(location: ConnectionSpec.Location, trigger: UserInitiatedVPNChange.VPNTrigger?)
        case disconnect
        case select(String)
        case loaded(CityStateListType)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        public enum Alert: Equatable {
            case maintenance
        }

        public enum Delegate: Equatable {
            case dismissRequested
        }
    }

    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.defaultConnectionStorage) private var defaultConnectionStorage
    @Dependency(\.switchToPrimaryTab) private var switchToPrimaryTab

    public init() {}

    public var body: some Reducer<State, Action> {
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
                log.warning("Displaying Server under maintenance alert")
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
                case .gateways, .secureCores:
                    // This sheet is designed to list grouped cities/states only.
                    // Gateways and secure-core rows are handled by dedicated flows, so no section title is shown here.
                    assertionFailure("Unexpected non city/state list type in CityStateListFeature: \(type)")
                    state.sectionTitle = nil
                }
                return .none
            case let .select(name):
                if let listType = state.listState.loadedType {
                    switch listType {
                    case .cities:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .city(name))))
                    case .states:
                        state.path.append(.serversList(.init(countryCode: state.countryCode, listType: .state(name))))
                    case .gateways, .secureCores:
                        // This sheet is designed for city/state drill-down only.
                        // Gateways and secure-core lists should never route through this selection path.
                        assertionFailure("Unexpected city/state selection for list type: \(listType)")
                    }
                }
                return .none
            case .disconnect:
                let disconnectTrigger = if let listType = state.listState.loadedType {
                    listType.telemetryTrigger
                } else {
                    UserInitiatedVPNChange.VPNTrigger.country
                }

                return .run { [disconnectVPN] _ in
                    try await disconnectVPN(disconnectTrigger)
                } catch: { error, _ in
                    log.error("Failed to disconnect from VPN from \(#file):\(#line) with error: \(error)")
                    SentryHelper.shared?.log(message: "Failed to disconnect from city/state list.", extra: [
                        "source": "CityStateListFeature.disconnect",
                        "trigger": "\(disconnectTrigger)",
                        "error": "\(error)",
                    ])
                    SentryHelper.shared?.log(error: error)
                }
            case let .connect(location, trigger):
                let spec = CityStateConnectionSpecFactory.makeSpec(location: location)
                let connectionProtocol = (try? defaultConnectionStorage.getDefaultProtocol()) ?? .smartProtocol
                let listTrigger = if let listType = state.listState.loadedType {
                    listType.telemetryTrigger
                } else {
                    UserInitiatedVPNChange.VPNTrigger.countriesCity
                }

                return .run { [connectToVPN] send in
                    try await connectToVPN(spec, connectionProtocol, trigger ?? listTrigger)
                    await switchToPrimaryTab()
                    await send(.delegate(.dismissRequested))
                } catch: { error, _ in
                    log.error("Failed to connect to VPN from \(#file):\(#line) with error: \(error)")
                    SentryHelper.shared?.log(message: "Failed to connect to location/trigger.", extra: [
                        "source": "CityStateListFeature.connect",
                        "trigger": "\(listTrigger)",
                        "error": "\(error)",
                    ])
                    SentryHelper.shared?.log(error: error)
                }
            case let .path(.element(_, action: .serversList(.connect(location)))):
                return .send(.connect(location: location, trigger: .countriesServer))
            case .path(.element(_, action: .serversList(.disconnect))):
                return .send(.disconnect)
            case .path, .alert, .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Path.State Equatable Conformance

extension CityStateListFeature.Path.State: Equatable {}
