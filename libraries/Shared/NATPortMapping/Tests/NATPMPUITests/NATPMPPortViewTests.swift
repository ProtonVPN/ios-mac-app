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
import Testing
import TestingErgonomics

/// The port sits in a popover the app gives a fixed width, so each state is recorded at the width the
/// design asks for. The active state repeats across locales, because it prints a date and a time.
@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct NATPMPPortViewTests {
    private static let activePort = SnapshotEnvironment.Layout.fixed(CGSize(width: 290, height: 84))
    /// The same view in the narrower popover, where the label wraps onto a second line.
    private static let narrowActivePort = SnapshotEnvironment.Layout.fixed(CGSize(width: 190, height: 84))
    private static let portMessage = SnapshotEnvironment.Layout.fixed(CGSize(width: 268, height: 66))
    private static let portStatus = SnapshotEnvironment.Layout.fixed(CGSize(width: 188, height: 25))

    /// When the port was last renewed. Fixed, because the view prints it.
    private static let updateDate = Date(timeIntervalSince1970: 1_757_929_224)

    @Test
    func loadedViewEnUS() {
        withLocale("en_US") {
            assertSnapshot(of: activePortView, layout: Self.activePort, appearance: .light)
        }
    }

    @Test
    func loadedViewEnUSBut2Lines() {
        withLocale("en_US") {
            assertSnapshot(of: activePortView, layout: Self.narrowActivePort, appearance: .light)
        }
    }

    @Test
    func loadedViewDarkEnUK() {
        withLocale("en_UK") {
            assertSnapshot(of: activePortView, layout: Self.activePort)
        }
    }

    @Test
    func loadedViewEsES() {
        withLocale("es_ES") {
            assertSnapshot(of: activePortView, layout: Self.activePort, appearance: .light)
        }
    }

    @Test
    func loadedViewDarkFrCH() {
        withLocale("fr_CH") {
            assertSnapshot(of: activePortView, layout: Self.activePort)
        }
    }

    @Test
    func loadedViewDeCH() {
        withLocale("de_CH") {
            assertSnapshot(of: activePortView, layout: Self.activePort, appearance: .light)
        }
    }

    @Test
    func loadedViewDarkUk() {
        withLocale("uk") {
            assertSnapshot(of: activePortView, layout: Self.activePort)
        }
    }

    @Test
    func loadingView() {
        assertSnapshot(of: LoadingPortView(), layout: Self.portMessage, appearance: .light)
    }

    @Test
    func loadingViewDark() {
        assertSnapshot(of: LoadingPortView(), layout: Self.portMessage)
    }

    @Test
    func statusView() {
        assertSnapshot(of: StatusPortView(portNumber: 36528), layout: Self.portStatus, appearance: .light)
    }

    @Test
    func statusViewDark() {
        assertSnapshot(of: StatusPortView(portNumber: 36528), layout: Self.portStatus)
    }

    @Test
    func errorView() {
        assertSnapshot(of: PortErrorView(), layout: Self.portMessage, appearance: .light)
    }

    @Test
    func errorViewDark() {
        assertSnapshot(of: PortErrorView(), layout: Self.portMessage)
    }

    // MARK: - Private

    private var activePortView: ActivePortView {
        ActivePortView(portNumber: 36528, updateDate: Self.updateDate)
    }

    /// Renders `operation` against `identifier`, and against the one time zone, so the date and time the
    /// view prints don't follow the machine the references were recorded on.
    private func withLocale(_ identifier: String, _ operation: () -> Void) {
        withDependencies {
            $0.locale = Locale(identifier: identifier)
            $0.timeZone = .gmt
        } operation: {
            operation()
        }
    }
}

extension NATPMPPortViewTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Shared/NATPortMapping/Tests/NATPMPUITests")
    }
}
