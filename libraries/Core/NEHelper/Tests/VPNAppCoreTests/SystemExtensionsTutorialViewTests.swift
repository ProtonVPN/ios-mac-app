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

#if canImport(AppKit)

    import Dependencies
    import Foundation
    import SnapshotTesting
    import SwiftUI
    import Testing
    @testable import VPNAppCore

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct SystemExtensionsTutorialViewTests {
        @Test
        func firstAppLaunchNotSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: false,
                origin: .firstAppLaunch
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func firstAppLaunchSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: true,
                origin: .firstAppLaunch
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func justWireguardNotSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: false,
                origin: .inAppPrompt([.wireguard])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func justWireguardSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: true,
                origin: .inAppPrompt([.wireguard])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func justSplitTunnelingNotSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: false,
                origin: .inAppPrompt([.splitTunneling])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func justSplitTunnelingSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: true,
                origin: .inAppPrompt([.splitTunneling])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func inAppPromptBothNotSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: false,
                origin: .inAppPrompt([.wireguard, .splitTunneling])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func inAppPromptBothSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: true,
                origin: .inAppPrompt([.wireguard, .splitTunneling])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func helpMenuNotSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: false,
                origin: .inAppPrompt([])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }

        @Test
        func helpMenuSequoia() {
            let view = SystemExtensionsTutorialView(
                isSequoiaOrNewer: true,
                origin: .inAppPrompt([])
            )
            .colorScheme(.dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: SystemExtensionsTutorialView.viewSize))
        }
    }

#endif
