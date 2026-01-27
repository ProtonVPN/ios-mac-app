//
//  Created on 27/01/2026 by Max Kupetskyi.
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
import Dependencies

@Reducer
public struct SearchResultsFeature {
    @ObservableState
    public enum State: Equatable {
        case placeholder
        case noResults
        case resultsDisplay(SearchResultsDisplayFeature.State)
        case recentSearches(SearchRecentsFeature.State)
    }

    public enum Action {
        case resultsDisplay(SearchResultsDisplayFeature.Action)
        case recentSearches(SearchRecentsFeature.Action)
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .resultsDisplay:
                .none

            case .recentSearches:
                .none
            }
        }
        .ifCaseLet(\.resultsDisplay, action: \.resultsDisplay) {
            SearchResultsDisplayFeature()
        }
        .ifCaseLet(\.recentSearches, action: \.recentSearches) {
            SearchRecentsFeature()
        }
    }
}
