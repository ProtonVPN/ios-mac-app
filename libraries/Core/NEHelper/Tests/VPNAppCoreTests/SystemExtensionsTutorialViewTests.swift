//
//  Created on 2025-08-25 by Pawel Jurczyk.
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

    import Foundation
    import SnapshotTesting
    import Testing
    import TestingErgonomics
    @testable import VPNAppCore

    /// The tutorial names the extensions the app is waiting for, and Sequoia moves the setting the user has
    /// to reach, so every case is one combination of the two.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct SystemExtensionsTutorialViewTests {
        /// The window the app shows the tutorial in has the size the view itself asks for.
        private static let layout = SnapshotEnvironment.Layout.fixed(SystemExtensionsTutorialView.viewSize)

        @Test
        func firstAppLaunchNotSequoia() {
            assertSnapshot(of: Self.view(isSequoiaOrNewer: false, origin: .firstAppLaunch), layout: Self.layout)
        }

        @Test
        func firstAppLaunchSequoia() {
            assertSnapshot(of: Self.view(isSequoiaOrNewer: true, origin: .firstAppLaunch), layout: Self.layout)
        }

        @Test
        func justWireguardNotSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: false, origin: .inAppPrompt([.wireguard])),
                layout: Self.layout
            )
        }

        @Test
        func justWireguardSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: true, origin: .inAppPrompt([.wireguard])),
                layout: Self.layout
            )
        }

        @Test
        func justSplitTunnelingNotSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: false, origin: .inAppPrompt([.splitTunneling])),
                layout: Self.layout
            )
        }

        @Test
        func justSplitTunnelingSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: true, origin: .inAppPrompt([.splitTunneling])),
                layout: Self.layout
            )
        }

        @Test
        func inAppPromptBothNotSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: false, origin: .inAppPrompt([.wireguard, .splitTunneling])),
                layout: Self.layout
            )
        }

        @Test
        func inAppPromptBothSequoia() {
            assertSnapshot(
                of: Self.view(isSequoiaOrNewer: true, origin: .inAppPrompt([.wireguard, .splitTunneling])),
                layout: Self.layout
            )
        }

        @Test
        func helpMenuNotSequoia() {
            assertSnapshot(of: Self.view(isSequoiaOrNewer: false, origin: .inAppPrompt([])), layout: Self.layout)
        }

        @Test
        func helpMenuSequoia() {
            assertSnapshot(of: Self.view(isSequoiaOrNewer: true, origin: .inAppPrompt([])), layout: Self.layout)
        }

        // MARK: - Private

        private static func view(
            isSequoiaOrNewer: Bool,
            origin: SystemExtensionTourAlert.Origin
        ) -> SystemExtensionsTutorialView {
            SystemExtensionsTutorialView(isSequoiaOrNewer: isSequoiaOrNewer, origin: origin)
        }
    }

    extension SystemExtensionsTutorialViewTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Core/NEHelper/Tests/VPNAppCoreTests")
        }
    }

#endif
