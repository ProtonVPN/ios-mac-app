//
//  Created on 10/04/2026 by Max Kupetskyi.
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
    import ComposableArchitecture
    @testable import Countries_macOS
    import CountriesShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct FeaturesInfoSheetViewSnapshotTests {
        @Test("Features info services sheet")
        func featuresInfoServicesSheetView() {
            var state = ServersFeaturesInformationFeature.State.servicesInfo
            state.screenTitle = "Features"
            let view = ServersFeaturesInformationView(
                store: Store(
                    initialState: state
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)
            assertFeaturesSnapshot(view: view, named: "featuresInfoServicesSheetView", snapshotSize: CGSize(width: 300, height: 690))
        }

        @Test("Features info gateways sheet")
        func featuresInfoGatewaysSheetView() {
            var state = ServersFeaturesInformationFeature.State.gatewaysInfo
            state.screenTitle = "Gateways"
            let view = ServersFeaturesInformationView(
                store: Store(
                    initialState: state
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)
            assertFeaturesSnapshot(view: view, named: "featuresInfoGatewaysSheetView", snapshotSize: CGSize(width: 300, height: 320))
        }

        private func assertFeaturesSnapshot(view: some View, named: String, snapshotSize: CGSize) {
            let nsView = NSHostingView(rootView: view)
            nsView.appearance = NSAppearance(named: .darkAqua)
            nsView.frame = CGRect(origin: .zero, size: snapshotSize)

            // Attach to a window and run a cycle so List-backed content renders rows.
            let window = NSWindow(
                contentRect: CGRect(origin: .zero, size: snapshotSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = nsView
            window.layoutIfNeeded()
            nsView.layoutSubtreeIfNeeded()

            assertSnapshot(
                of: nsView,
                as: .wait(for: 0.05, on: .image(size: snapshotSize)),
                testName: named
            )
        }
    }

    extension FeaturesInfoSheetViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
