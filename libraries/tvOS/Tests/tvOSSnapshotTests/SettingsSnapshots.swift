//
//  Created on 07/06/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import XCTest
import SnapshotTesting
import ComposableArchitecture
@testable import tvOS
import SwiftUI
@testable import CommonNetworking
@testable import ExtensionManager
@testable import LocalAgent
import Ergonomics

final class SettingsFeatureSnapshotTests: TVSnapshotTestCase {
    func testLightSettings() {
        settings(trait: .light)
    }

    func testDarkSettings() {
        settings(trait: .dark)
    }

    func settings(trait: UIUserInterfaceStyle) {
        let store = Store(initialState: AppFeature.State(
            main: .init(
                currentTab: .settings,
                mainBackground: .clear
            ),
            networking: .authenticated(.auth(uid: ""))
        )) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager()
        }

        @Shared(.userDisplayName) var userDisplayName: String?
        $userDisplayName.withLock { $0 = "test user" }
        @Shared(.userTier) var userTier: Int?
        $userTier.withLock { $0 = .paidTier }

        let appView = NavigationStack {
            AppView(store: store)
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))

        snap(appView, caseName: "1 List", trait: trait)
        store.send(.main(.settings(.showDrillDown(.contactUs))))
        snap(appView, caseName: "2 ContactUs", trait: trait)
        store.send(.main(.settings(.showDrillDown(.supportCenter))))
        snap(appView, caseName: "3 SupportCenter", trait: trait)
        store.send(.main(.settings(.showDrillDown(.privacyPolicy))))
        snap(appView, caseName: "4 PrivacyPolicy", trait: trait)
        store.send(.main(.settings(.showDrillDown(.eula))))
        snap(appView, caseName: "5 EULA", trait: trait)
    }
}
