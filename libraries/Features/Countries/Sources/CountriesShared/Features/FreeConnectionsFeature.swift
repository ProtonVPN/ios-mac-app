//
//  Created on 12/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
import Foundation

@Reducer
public struct FreeConnectionsFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public struct Country: Equatable, Identifiable, Sendable {
            public let code: String
            public let name: String

            public var id: String { code }

            public init(code: String, name: String) {
                self.code = code
                self.name = name
            }
        }

        public var countries: IdentifiedArrayOf<Country>

        public init(countries: IdentifiedArrayOf<Country>) {
            self.countries = countries
        }
    }

    public enum Action {
        case upgradeTapped
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .upgradeTapped:
                .none
            }
        }
    }
}

#if DEBUG
    public extension FreeConnectionsFeature.State {
        static let mock = Self(countries: [
            .init(code: "US", name: "United States"),
            .init(code: "NL", name: "Netherlands"),
            .init(code: "JP", name: "Japan"),
        ])
    }
#endif
