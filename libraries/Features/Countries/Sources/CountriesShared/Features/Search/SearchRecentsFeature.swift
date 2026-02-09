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
public struct SearchRecentsFeature {
    @ObservableState
    public struct State: Equatable {
        var recentSearches: [String] = []

        var isEmpty: Bool {
            recentSearches.isEmpty
        }
    }

    public enum Action {
        case onAppear
        case load
        case clear
        case recentTapped(String)
    }

    @Dependency(\.searchStorageNew) private var searchStorage

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.load)

            case .load:
                let recent = searchStorage.get()
                state.recentSearches = recent
                return .none

            case .clear:
                state.recentSearches = []
                searchStorage.clear()
                return .none

            case .recentTapped:
                return .none
            }
        }
    }
}
