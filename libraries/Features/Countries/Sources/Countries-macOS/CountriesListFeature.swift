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
public struct CountriesListFeature: Sendable {

    @ObservableState
    public struct State {

        private var _scrollPosition: Any?
        @available(macOS 15.0, *)
        var scrollPosition: ScrollPosition {
            get { (_scrollPosition as? ScrollPosition) ?? ScrollPosition(edge: .top) }
            set { _scrollPosition = newValue }
        }
        public var sections: IdentifiedArrayOf<CityStateListFeature.State> = []

        var sectionTitle: String?

        var searchText: String?

        var expandedCountryCode: String?

        var listState: ListState = .loading

        enum ListState: Equatable {
            case loading
            case loaded([ServerGroupInfo])
        }

        public init() {
            if #available(macOS 15, *) {
                _scrollPosition = ScrollPosition(edge: .top)
            }
        }

        public init(groups: [ServerGroupInfo]) {
            self.listState = .loaded(groups)
        }
    }

    public enum Action: BindableAction {
        case searchText(String)
        case binding(BindingAction<State>)
        case didAppear
        case getGroups
        case loaded([ServerGroupInfo])
        case unselect
        case updateScrollPosition(code: String)
        case sections(IdentifiedActionOf<CityStateListFeature>)
    }

    public init() { }

    @Dependency(\.mainQueue) var mainQueue

    private enum CancelID {
      case debounceRequest
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .send(.getGroups)
            case .getGroups:
                return .run { [search = state.searchText ?? ""] send in
                    @Dependency(\.serverRepository) var repository
                    print("getGroups \(search)")
                    let countries = repository
                        .getGroups(
                            filteredBy: [.isNotUnderMaintenance, .kind(.country), .matches(search)],
                            groupedBy: .serverType
                        )

                    await send(.loaded(countries))
                } catch: { error, send in
                    print("cancelled")

                }

            case let .loaded(groups):
                state.listState = .loaded(groups)
                state.sections = .init(uniqueElements: groups.compactMap {
                    guard case let .country(code) = $0.kind else { return nil }
                    let listType = CityStateListType(countryCode: code)
                    return CityStateListFeature.State(countryCode: code, groupInfo: $0, listType: listType)
                })

                return .none
            case .unselect:
                state.expandedCountryCode = nil
                return .none
            case let .sections(.element(id, action: .expand)):
                if let code = state.expandedCountryCode {
                    state.sections[id: code]?.isExpanded = false // collapse the previous one
                    if code == id {
                        state.expandedCountryCode = nil // none is expanded
                    } else {
                        state.expandedCountryCode = id // mark the new expanded one
                        return .send(.updateScrollPosition(code: id))
                    }
                } else {
                    state.expandedCountryCode = id
                    return .send(.updateScrollPosition(code: id))
                }
                return .none
            case let .updateScrollPosition(code):
                if #available(macOS 15.0, *) {
                    state.scrollPosition.scrollTo(id: code)
                }
                return .none
            case .sections:
                return .none
            case .binding:
                return .none
            case let .searchText(text):
                state.searchText = text
                state.listState = .loading
                return .send(.getGroups)
                    .debounce(id: CancelID.debounceRequest,
                              for: 0.5,
                              scheduler: mainQueue)
            }
        }
        .forEach(\.sections, action: \.sections) {
            CityStateListFeature()
        }
    }
}

