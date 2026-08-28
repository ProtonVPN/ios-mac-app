//
//  Created on 26/08/2026 by Max Kupetskyi.
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
    import Dependencies
    import Foundation
    import ModalsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import VPNAppCore
    import VPNShared

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct TelemetryTogglesViewSnapshotTests {
        @Test("Both answers are yes")
        func sharingEverything() {
            assert(sharesUsageData: true, sharesCrashReports: true)
        }

        @Test("Both answers are no")
        func sharingNothing() {
            assert(sharesUsageData: false, sharesCrashReports: false)
        }

        /// The two rows used to share one binding through a single `Shared<String>`, so a mixed
        /// answer is the case worth pinning down.
        @Test("Usage statistics on, crash reports off")
        func sharingOnlyUsageData() {
            assert(sharesUsageData: true, sharesCrashReports: false)
        }

        private func assert(
            sharesUsageData: Bool,
            sharesCrashReports: Bool,
            fileID: StaticString = #fileID,
            file: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            // A suite of its own per test, so one test's answers can't drive another's view. The
            // keychain has to report a user because these answers are stored per user.
            let keychain = MockAuthKeychain()
            keychain.setMockUsername("snapshot-user")

            withDependencies {
                $0.defaultAppStorage = .inMemory
                $0.authKeychain = keychain
            } operation: {
                TelemetryOptIn.record(
                    sharesUsageData: sharesUsageData,
                    sharesCrashReports: sharesCrashReports
                )

                // Pinned to the top against a filled background, which is how
                // `TelemetrySettingsViewController` lays it out on iOS.
                let view = TelemetrySettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(.background, .weak))
                    .environment(\.colorScheme, .dark)

                assertSnapshot(
                    of: view,
                    as: .image(layout: .device(config: .iPhone13Mini)),
                    fileID: fileID,
                    file: file,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
        }
    }

    extension TelemetryTogglesViewSnapshotTests: @preconcurrency AssertSnapshot {
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
