//
//  Created on 17/02/2026 by Max Kupetskyi.
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

import ComposableArchitecture
@testable import ios_app
import PMLogger
import SnapshotTesting
import System
import Testing
import UIKit

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct LogSelectionViewControllerSnapshotTests {
    @Test("Log selection contains app, wireguard and apple tv logs")
    func logSelectionAllRowsVisible() {
        let state = LogSelectionFeature.State(
            rows: [
                .logSource(.app),
                .logSource(.wireguard),
                .downloadAppleTVLogs,
            ]
        )
        let store = StoreOf<LogSelectionFeature>(initialState: state) {
            EmptyReducer()
        }
        let viewController = LogSelectionViewController(store: store)
        let navigationController = UINavigationController(rootViewController: viewController)

        assertSnapshot(
            of: navigationController,
            as: .image(on: .iPhone13Pro, traits: UITraitCollection(userInterfaceStyle: .dark))
        )
    }
}

extension LogSelectionViewControllerSnapshotTests: AssertSnapshot {
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
