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

        @Test("Connection details", arguments: locales)
        func connectionDetails(locale: Locale) {
            assert(state: Self.state(), locale: locale, named: "connectionDetails_\(locale.identifier)")
        }

        @Test("Connection details without a city")
        func withoutCity() {
            assert(state: Self.state(city: "-"), locale: SnapshotFixtures.localeEnUS)
        }

        @Test("Connection details under load")
        func underLoad() {
            assert(state: Self.state(serverLoad: 91), locale: SnapshotFixtures.localeEnUS)
        }

        /// Overrides must wrap the *render* (assertSnapshot), not just view construction —
        /// `@Dependency(\.locale)` is read during body evaluation.
        private func assert(
            state: ConnectionDetailsFeature.State,
            locale: Locale,
            named name: String? = nil,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            withDependencies {
                $0.locale = locale
            } operation: {
                assertSnapshot(
                    of: Self.view(state: state),
                    as: .image(layout: .sizeThatFits),
                    named: name,
                    fileID: fileID,
                    file: filePath,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
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

        private static func view(state: ConnectionDetailsFeature.State) -> some View {
            ConnectionDetailsView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .frame(width: SnapshotFixtures.phoneWidth)
                .background(Color(.background, .strong))
                .environment(\.colorScheme, .dark)
        }
    }

    extension ConnectionDetailsViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
