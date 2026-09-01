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

#if os(macOS)
    import ComposableArchitecture
    import Dependencies
    import ModalsShared
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics
    import VPNAppCore
    import VPNShared

    /// The consent screen as macOS frames it: a window of its own, with a heading and a confirm button.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct TelemetryConsentWindowSnapshotTests {
        typealias Appearance = SnapshotEnvironment.Appearance

        /// The window is as wide as the design asks and as tall as the questions it lists.
        private static let layout = SnapshotEnvironment.Layout.fitting(width: 420)

        @Test("Opens with both answers on", arguments: Appearance.allCases)
        func opensWithBothOn(appearance: Appearance) {
            assert(appearance: appearance, storedSharesUsageData: false, storedSharesCrashReports: false)
        }

        // MARK: - Private

        private func assert(
            appearance: Appearance,
            storedSharesUsageData: Bool,
            storedSharesCrashReports: Bool,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
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
                    sharesUsageData: storedSharesUsageData,
                    sharesCrashReports: storedSharesCrashReports
                )

                assertSnapshot(
                    of: Self.view(),
                    layout: Self.layout,
                    appearance: appearance,
                    named: appearance.rawValue,
                    fileID: fileID,
                    file: filePath,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
        }

        private static func view() -> some View {
            TelemetryConsentView(store: Store(initialState: TelemetryConsentFeature.State()) { EmptyReducer() })
        }
    }

    extension TelemetryConsentWindowSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Modals/Tests/ModalsTests")
        }
    }
#endif
