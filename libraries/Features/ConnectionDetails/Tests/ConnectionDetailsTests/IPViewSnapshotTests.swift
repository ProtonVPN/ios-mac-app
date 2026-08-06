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
    import Domain
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import Theme

    /// The row pairs the user's own address with the one their traffic leaves from, so each case is a
    /// combination of what is known and what is concealed.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct IPViewSnapshotTests {
        // Both keys are process-wide, hence `.serialized` and a known baseline per test.
        @Shared(.connectionState) private var connectionState: ConnectionState
        @Shared(.userLocation) private var userLocation: StoredUserLocation?

        init() {
            $connectionState.withLock { $0 = SnapshotFixtures.connected() }
            $userLocation.withLock { $0 = .measured(.init(ip: "31.14.72.5", country: "PL", isp: "Play"), at: .now) }
        }

        @Test("My IP concealed")
        func concealed() {
            assertSnapshot(of: Self.view(), as: .image(layout: .sizeThatFits))
        }

        @Test("My IP revealed")
        func revealed() {
            var state = IPViewFeature.State()
            state.userIPHidden = false
            assertSnapshot(of: Self.view(state: state), as: .image(layout: .sizeThatFits))
        }

        /// Nothing has measured the user's own address yet: the row says so rather than masking a value
        /// that doesn't exist, and offers no reveal button.
        @Test("My IP unknown")
        func unknown() {
            $userLocation.withLock { $0 = nil }
            assertSnapshot(of: Self.view(), as: .image(layout: .sizeThatFits))
        }

        /// The tunnel hasn't reported an exit address and the server list carries none either.
        @Test("VPN IP unknown")
        func vpnIPUnknown() {
            $connectionState.withLock { $0 = .disconnected }
            assertSnapshot(of: Self.view(), as: .image(layout: .sizeThatFits))
        }

        private static func view(state: IPViewFeature.State = .init()) -> some View {
            IPView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .frame(width: SnapshotFixtures.phoneWidth)
                .background(Color(.background, .strong))
                .environment(\.colorScheme, .dark)
        }
    }

    extension IPViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
