//
//  Created on 12/03/2026 by Max Kupetskyi.
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
import Foundation

/// Lists the countries a free user can connect to, and offers an upgrade for the rest of the network.
///
/// Home presents it when a free user taps the connection card, Countries when they tap the info button next to
/// the free connections. The parent owns both the presentation and the upsell that `upgradeTapped` asks for.
@Reducer
public struct FreeConnectionsFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        /// One country in the list, already named in the user's language.
        public struct Country: Equatable, Identifiable, Sendable {
            public let code: String
            public let name: String

            public var id: String {
                code
            }

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
        /// The user tapped the banner. The parent presents the upsell.
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
