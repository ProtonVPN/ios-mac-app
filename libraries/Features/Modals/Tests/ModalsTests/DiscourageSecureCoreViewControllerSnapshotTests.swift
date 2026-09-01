//
//  Created on 13/03/2026 by Max Kupetskyi.
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

#if os(macOS)
    import ComposableArchitecture
    @testable import Modals_macOS
    import ModalsShared
    import SnapshotTesting
    import Strings
    import SwiftUI
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct DiscourageSecureCoreViewControllerSnapshotTests {
        /// The size of the window the app shows the modal in.
        private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 520, height: 630))

        @Test("default dark appearance")
        func defaultAppearance() {
            assertSnapshot(of: Self.view(state: .init()), layout: Self.layout)
        }

        @Test("default dark appearance with SC available (no reconnect notice)")
        func defaultAppearanceWithSameCountryReconnectNotice() {
            assertSnapshot(
                of: Self.view(state: .init(reconnectNotice: Localizable.viewToggleOnReconnectSameCountry)),
                layout: Self.layout
            )
        }

        private static func view(state: DiscourageSecureCoreFeature.State) -> some View {
            DiscourageSecureCoreView(store: Store(initialState: state) { EmptyReducer() })
                .background(Color(.background))
        }
    }

    extension DiscourageSecureCoreViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Modals/Tests/ModalsTests")
        }
    }
#endif
