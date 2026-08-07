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
    import Connection
    @testable import ConnectionDetails_iOS
    @testable import ConnectionDetailsShared
    import DependenciesTestSupport
    import Domain
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import Theme

    /// The whole sheet: the connection header, both IP columns, the details rows and the feature panels.
    ///
    /// The locale is pinned as a suite trait rather than around each assertion: the header localizes
    /// country names while SwiftUI lays the view out, which happens outside any `withDependencies`
    /// scope a test could wrap the call in.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing), .dependency(\.locale, SnapshotFixtures.locale))
    struct ConnectionScreenViewSnapshotTests {
        @Shared(.connectionState) private var connectionState: ConnectionState
        @Shared(.userLocation) private var userLocation: StoredUserLocation?

        init() {
            $userLocation.withLock { $0 = .measured(.init(ip: "31.14.72.5", country: "PL", isp: "Play"), at: .now) }
        }

        @Test("Connection screen")
        func connectionScreen() throws {
            $connectionState.withLock { $0 = SnapshotFixtures.connected() }
            try assertSnapshot(of: Self.view(connectionState), as: .image(layout: .device(config: .iPhone13Mini)))
        }

        /// Secure Core adds its own panel above the server's features, and the header shows the entry hop.
        @Test("Connection screen on Secure Core")
        func secureCoreConnectionScreen() throws {
            $connectionState.withLock { $0 = SnapshotFixtures.connectedToSecureCore() }
            try assertSnapshot(of: Self.view(connectionState), as: .image(layout: .device(config: .iPhone13Mini)))
        }

        /// A server with no features at all drops the whole features section.
        @Test("Connection screen without features")
        func withoutFeatures() throws {
            $connectionState.withLock { $0 = SnapshotFixtures.connected(server: SnapshotFixtures.server(features: [])) }
            try assertSnapshot(of: Self.view(connectionState), as: .image(layout: .device(config: .iPhone13Mini)))
        }

        private static func view(_ connectionState: ConnectionState) throws -> some View {
            let state = try #require(connectionState.connectionScreenFeatureState())
            return ConnectionScreenView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .background(Color(.background, .strong))
                .environment(\.colorScheme, .dark)
        }
    }

    extension ConnectionScreenViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
