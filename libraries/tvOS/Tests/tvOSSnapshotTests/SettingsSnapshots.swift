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

class SettingsFeatureSnapshotTests: XCTestCase {
    
    func testLightSettings() {
        settings(trait: .light)
    }

    func testDarkSettings() {
        settings(trait: .dark)
    }

    func settings(trait: Trait) {
        let store = Store(initialState: AppFeature.State(main: .init(currentTab: .settings,
                                                                     mainBackground: .clear),
                                                         networking: .authenticated(.auth(uid: "")))) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager()
        }

        @Shared(.userDisplayName) var userDisplayName: String?
        userDisplayName = "test user"

        let appView = NavigationStack {
            AppView(store: store)
        }
            .frame(.rect(width: 1920, height: 1080))
            .background(Color(.background, .strong))

        assertSnapshot(of: appView, as: .image(traits: trait.rawValue), testName: "1 List " + trait.name)
        store.send(.main(.settings(.showDrillDown(.contactUs))))
        assertSnapshot(of: appView, as: .image(traits: trait.rawValue), testName: "2 ContactUs " + trait.name)
        store.send(.main(.settings(.showDrillDown(.supportCenter))))
        assertSnapshot(of: appView, as: .image(traits: trait.rawValue), testName: "3 SupportCenter " + trait.name)
        store.send(.main(.settings(.showDrillDown(.privacyPolicy))))
        assertSnapshot(of: appView, as: .image(traits: trait.rawValue), testName: "4 PrivacyPolicy " + trait.name)
    }
}
