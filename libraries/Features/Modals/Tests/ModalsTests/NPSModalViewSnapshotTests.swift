//
//  Created on 2026-08-26 by Pawel Jurczyk.
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

#if os(iOS)
    import ComposableArchitecture
    @testable import ModalsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct NPSModalViewSnapshotTests {
        @Test("NPSModalView, modal start")
        func npsModalViewModalStart() {
            let view = NPSModalView(
                store: Store(initialState: NPSModalFeature.State()) {
                    EmptyReducer()
                }
            )
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("NPSModalView, score selected")
        func npsModalViewScoreSelected() {
            let view = NPSModalView(
                store: Store(initialState: NPSModalFeature.State(score: 7)) {
                    EmptyReducer()
                }
            )
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("NPSModalView, score selected with a comment")
        func npsModalViewScoreSelectedWithComment() {
            let view = NPSModalView(
                store: Store(
                    initialState: NPSModalFeature.State(score: 10, comment: "Fast and private.")
                ) {
                    EmptyReducer()
                }
            )
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }
    }

    extension NPSModalViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Modals/Tests/ModalsTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
