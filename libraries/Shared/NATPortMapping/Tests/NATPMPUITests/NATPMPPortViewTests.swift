//
//  Created on 28/07/2025 by Max Kupetskyi.
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

import Dependencies
import Foundation
@testable import NATPMPUI
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct NATPMPPortViewTests {
    @Test
    func loadedView() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date().addingTimeInterval(-35 * 60), // 35 minutes ago
                responseDate: Date()
            )
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 84)))
        }
    }

    @Test
    func loadedViewDark() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date().addingTimeInterval(-35 * 60), // 35 minutes ago
                responseDate: Date()
            ).environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 84)))
        }
    }

    @Test
    func loadingView() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = LoadingPortView()
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 66)))
        }
    }

    @Test
    func loadingViewDark() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = LoadingPortView().environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 66)))
        }
    }

    @Test
    func statusView() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = StatusPortView(portModel: MappedPort(portNumber: 36528))
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 188, height: 25)))
        }
    }

    @Test
    func statusViewDark() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = StatusPortView(portModel: MappedPort(portNumber: 36528)).environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 188, height: 25)))
        }
    }
}
