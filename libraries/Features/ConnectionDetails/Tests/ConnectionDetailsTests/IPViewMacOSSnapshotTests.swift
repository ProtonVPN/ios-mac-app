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
    import System
    import Testing
    import TestingErgonomics
    import Theme

    /// The desktop row carries the same states as the phone one, in the sidebar's narrower column.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct IPViewMacOSSnapshotTests {
        private static let size = CGSize(width: 320, height: 72)

        @Shared(.connectionState) private var connectionState: ConnectionState
        @Shared(.userLocation) private var userLocation: StoredUserLocation?

        init() {
            // The theme's colours resolve against the running app's appearance, not the SwiftUI
            // environment or the hosting view's — the app pins both of these on launch.
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            AppTheme.useVPNBrand()
            $connectionState.withLock { $0 = SnapshotFixtures.connected() }
            $userLocation.withLock { $0 = .measured(.init(ip: "31.14.72.5", country: "PL", isp: "Play"), at: .now) }
        }

        @Test("My IP concealed (macOS)")
        func concealed() {
            assertSnapshot(of: Self.hostingView(), as: .image(size: Self.size))
        }

        @Test("My IP revealed (macOS)")
        func revealed() {
            var state = IPViewFeature.State()
            state.userIPHidden = false
            assertSnapshot(of: Self.hostingView(state: state), as: .image(size: Self.size))
        }

        /// Nothing has measured the user's own address yet: the row says so and offers no reveal button.
        @Test("My IP unknown (macOS)")
        func unknown() {
            $userLocation.withLock { $0 = nil }
            assertSnapshot(of: Self.hostingView(), as: .image(size: Self.size))
        }

        private static func hostingView(state: IPViewFeature.State = .init()) -> NSHostingView<some View> {
            let view = IPView(store: Store(initialState: state, reducer: { EmptyReducer() }))
                .background(Color(.background, .strong))
            return NSHostingView(rootView: view)
        }
    }

    extension IPViewMacOSSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
