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
    func loadedViewEnUS() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "en_US")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_929_224)
            )
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
        }
    }

    @Test
    func loadedViewEnUSBut2Lines() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "en_US")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_929_224)
            )
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 190, height: 84)))
        }
    }

    @Test
    func loadedViewDarkEnUK() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "en_UK")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_929_224)
            ).environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
        }
    }

    @Test
    func loadedViewEsES() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "es_ES")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_936_455)
            )
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
        }
    }

    @Test
    func loadedViewDarkFrCH() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "fr_CH")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_936_455)
            ).environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
        }
    }

    @Test
    func loadedViewDeCH() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "de_CH")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_936_455)
            )
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
        }
    }

    @Test
    func loadedViewDarkUk() {
        withDependencies {
            $0.date.now = .init()
            $0.locale = Locale(identifier: "uk")
        } operation: {
            let view = ActivePortView(
                portNumber: 36528,
                updateDate: Date(timeIntervalSince1970: 1_757_936_455)
            ).environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 290, height: 84)))
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

    @Test
    func statusAppKitView() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = StatusPortAppKitView()
            view.portNumber = 36528
            view.frame = .init(x: 0, y: 0, width: 188, height: 25)
            view.layoutSubtreeIfNeeded()

            assertSnapshot(of: view, as: .image(size: .init(width: 188, height: 25)))
        }
    }

    @Test
    func statusAppKitViewDark() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = StatusPortAppKitView()
            view.portNumber = 36528
            view.appearance = NSAppearance(named: .darkAqua)
            view.frame = .init(x: 0, y: 0, width: 188, height: 25)
            view.layoutSubtreeIfNeeded()

            assertSnapshot(of: view, as: .image(size: .init(width: 188, height: 25)))
        }
    }

    @Test
    func errorView() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = PortErrorView()
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 66)))
        }
    }

    @Test
    func errorViewDark() {
        withDependencies {
            $0.date.now = .init()
        } operation: {
            let view = PortErrorView().environment(\.colorScheme, .dark)
            let nsView = NSHostingView(rootView: view)

            assertSnapshot(of: nsView, as: .image(size: .init(width: 268, height: 66)))
        }
    }
}
