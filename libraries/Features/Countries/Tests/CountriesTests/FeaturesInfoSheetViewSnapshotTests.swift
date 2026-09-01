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
    import ComposableArchitecture
    @testable import Countries_macOS
    import CountriesShared
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics

    /// Both sheets are one list of features in the sidebar's width, tall enough to hold every row.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct FeaturesInfoSheetViewSnapshotTests {
        /// The sheets are as wide as the sidebar and as tall as the rows they list.
        private static let servicesSheet = SnapshotEnvironment.Layout.fixed(CGSize(width: 300, height: 690))
        private static let gatewaysSheet = SnapshotEnvironment.Layout.fixed(CGSize(width: 300, height: 320))

        @Test("Features info services sheet")
        func featuresInfoServicesSheetView() {
            var state = ServersFeaturesInformationFeature.State.servicesInfo
            state.screenTitle = "Features"
            assertSnapshot(of: Self.view(state: state), layout: Self.servicesSheet)
        }

        @Test("Features info gateways sheet")
        func featuresInfoGatewaysSheetView() {
            var state = ServersFeaturesInformationFeature.State.gatewaysInfo
            state.screenTitle = "Gateways"
            assertSnapshot(of: Self.view(state: state), layout: Self.gatewaysSheet)
        }

        private static func view(state: ServersFeaturesInformationFeature.State) -> some View {
            ServersFeaturesInformationView(store: Store(initialState: state) { EmptyReducer() })
                .background(Color(.background))
        }
    }

    extension FeaturesInfoSheetViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Countries/Tests/CountriesTests")
        }
    }
#endif
