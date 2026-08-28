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
    import AppKit
    import ComposableArchitecture
    import Dependencies
    import ModalsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import VPNAppCore
    import VPNShared

    /// The consent screen as macOS frames it: a window of its own, with a heading and a confirm button.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct TelemetryConsentWindowSnapshotTests {
        private let snapshotWidth: CGFloat = 420

        @Test("Opens with both answers on", arguments: Appearance.allCases)
        func opensWithBothOn(appearance: Appearance) {
            assert(appearance: appearance, storedSharesUsageData: false, storedSharesCrashReports: false)
        }

        enum Appearance: String, CaseIterable {
            case light
            case dark

            var name: NSAppearance.Name {
                self == .dark ? .darkAqua : .aqua
            }
        }

        private func assert(
            appearance: Appearance,
            storedSharesUsageData: Bool,
            storedSharesCrashReports: Bool,
            fileID: StaticString = #fileID,
            file: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            _ = NSApplication.shared
            // Other suites in this target render against whatever appearance is already set, so the one
            // this test picks has to be put back.
            let previousAppearance = NSApp.appearance
            defer { NSApp.appearance = previousAppearance }

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

                let (window, size) = makeWindow(appearance: appearance.name)
                assertSnapshot(
                    of: window.contentView!,
                    as: .image(size: size),
                    named: appearance.rawValue,
                    fileID: fileID,
                    file: file,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
        }

        private func makeWindow(appearance: NSAppearance.Name) -> (window: NSWindow, size: CGSize) {
            NSApp.appearance = NSAppearance(named: appearance)

            let view = TelemetryConsentView(
                store: Store(initialState: TelemetryConsentFeature.State()) {
                    EmptyReducer()
                }
            )
            let viewController = NSHostingController(rootView: view)
            let needed = viewController.sizeThatFits(in: CGSize(width: snapshotWidth, height: 0))
            let size = CGSize(width: snapshotWidth, height: needed.height)

            let window = NSWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: appearance)
            window.contentViewController = viewController
            window.setContentSize(size)
            window.layoutIfNeeded()
            viewController.view.layoutSubtreeIfNeeded()

            return (window, viewController.view.bounds.size)
        }
    }

    extension TelemetryConsentWindowSnapshotTests: @preconcurrency AssertSnapshot {
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
