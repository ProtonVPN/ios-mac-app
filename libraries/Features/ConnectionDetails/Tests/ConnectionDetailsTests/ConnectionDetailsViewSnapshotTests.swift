//
//  Created on 06/08/2026 by Max Kupetskyi.
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

#if os(iOS)
    import ComposableArchitecture
    @testable import ConnectionDetails_iOS
    @testable import ConnectionDetailsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import Theme

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct ConnectionDetailsViewSnapshotTests {
        private static let locales: [Locale] = [
            SnapshotFixtures.localeEnUS,
            SnapshotFixtures.localeEnUk,
            SnapshotFixtures.localeEsEs,
            SnapshotFixtures.localeFrCh,
            SnapshotFixtures.localeDeCh,
            SnapshotFixtures.localeUk,
        ]

        /// One reference per locale
        @Test("Connection details", arguments: locales)
        func connectionDetails(locale: Locale) {
            assertSnapshot(
                of: Self.view(state: Self.state(), locale: locale),
                as: .image(layout: .sizeThatFits),
                named: "connectionDetails_\(locale.identifier)"
            )
        }

        /// A server with no city drops that row rather than showing the placeholder the API sends.
        @Test("Connection details without a city")
        func withoutCity() {
            assertSnapshot(
                of: Self.view(state: Self.state(city: "-"), locale: SnapshotFixtures.localeEnUS),
                as: .image(layout: .sizeThatFits)
            )
        }

        @Test("Connection details under load")
        func underLoad() {
            assertSnapshot(
                of: Self.view(state: Self.state(serverLoad: 91), locale: SnapshotFixtures.localeEnUS),
                as: .image(layout: .sizeThatFits)
            )
        }

        private static func state(
            city: String = "Warsaw",
            serverLoad: Int = 42
        ) -> ConnectionDetailsFeature.State {
            .init(
                connectedSince: SnapshotFixtures.connectedSince,
                country: "Poland",
                city: city,
                server: "PL#42",
                serverLoad: serverLoad,
                protocolName: "WireGuard"
            )
        }

        private static func view(state: ConnectionDetailsFeature.State, locale: Locale) -> some View {
            ConnectionDetailsView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .frame(width: SnapshotFixtures.phoneWidth)
                .background(Color(.background, .strong))
                .environment(\.colorScheme, .dark)
                .environment(\.locale, locale)
        }
    }

    extension ConnectionDetailsViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
