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

#if os(macOS)
    import ComposableArchitecture
    import Connection
    @testable import ConnectionDetails_macOS
    @testable import ConnectionDetailsShared
    import Domain
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics
    import Theme

    /// The desktop row carries the same states as the phone one, in the sidebar's narrower column.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct IPViewMacOSSnapshotTests {
        /// The sidebar sets the row's width and the row takes the height its two lines need.
        private static let layout = SnapshotEnvironment.Layout.fitting(width: 320)

        @Shared(.connectionState) private var connectionState: ConnectionState
        @Shared(.userLocation) private var userLocation: StoredUserLocation?

        init() {
            $connectionState.withLock { $0 = SnapshotFixtures.connected() }
            $userLocation.withLock { $0 = .measured(.init(ip: "31.14.72.5", country: "PL", isp: "Play"), at: .now) }
        }

        @Test("My IP concealed (macOS)")
        func concealed() {
            assertSnapshot(of: Self.view(), layout: Self.layout)
        }

        @Test("My IP revealed (macOS)")
        func revealed() {
            var state = IPViewFeature.State()
            state.userIPHidden = false
            assertSnapshot(of: Self.view(state: state), layout: Self.layout)
        }

        /// Nothing has measured the user's own address yet: the row says so and offers no reveal button.
        @Test("My IP unknown (macOS)")
        func unknown() {
            $userLocation.withLock { $0 = nil }
            assertSnapshot(of: Self.view(), layout: Self.layout)
        }

        private static func view(state: IPViewFeature.State = .init()) -> some View {
            IPView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .background(Color(.background, .strong))
        }
    }

    extension IPViewMacOSSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
