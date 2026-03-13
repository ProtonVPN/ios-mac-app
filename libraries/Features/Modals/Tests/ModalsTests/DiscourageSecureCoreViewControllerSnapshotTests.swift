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
    import AppKit
    @testable import Modals_macOS
    import SnapshotTesting
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct DiscourageSecureCoreViewControllerSnapshotTests {
        private let snapshotSize = CGSize(width: 520, height: 579)

        @Test("default dark appearance")
        func defaultAppearance() {
            let viewController = DiscourageSecureCoreViewController()
            viewController.loadViewIfNeeded()
            viewController.view.appearance = NSAppearance(named: .darkAqua)
            viewController.view.frame = CGRect(origin: .zero, size: snapshotSize)
            viewController.view.layoutSubtreeIfNeeded()

            assertSnapshot(of: viewController.view, as: .image(size: snapshotSize))
        }
    }

    extension DiscourageSecureCoreViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
                return nil
            }
            let suite = FilePath(String(describing: #filePath)).lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Modals/Tests/ModalsTests/__Snapshots__/\(suite)"
        }
    }
#endif
