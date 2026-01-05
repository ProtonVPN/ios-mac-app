//
//  Created on 05/01/2026 by Max Kupetskyi.
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

@testable import ios_app
import SnapshotTesting
import SwiftUI
import System
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct DefaultProfileRowSnapshotTests {
    @Test("Fastest connection - disconnected")
    func defaultProfileFastest() {
        let view = DefaultProfileRow(viewModel: .fastestMock)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Random connection - disconnected")
    func defaultProfileRandom() {
        let view = DefaultProfileRow(viewModel: .randomMock)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("With extra margin")
    func defaultProfileWithExtraMargin() {
        let view = DefaultProfileRow(viewModel: .withExtraMarginMock)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Connected state")
    func defaultProfileConnected() {
        let view = DefaultProfileRow(viewModel: .connectedMock)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }

    @Test("Connecting state")
    func defaultProfileConnecting() {
        let view = DefaultProfileRow(viewModel: .connectingMock)
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 70)))
    }
}

extension DefaultProfileRowSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/ios_app/Tests/ios_appTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
