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

@testable import CommonNetworking
import ComposableArchitecture
import Ergonomics
@testable import ExtensionManager
@testable import LocalAgent
import SnapshotTesting
import SwiftUI
import System
import TestingErgonomics
@testable import tvos_app
import XCTest

@available(tvOS 17.0, *)
final class SettingsFeatureSnapshotTests: XCTestCase {
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
            $0.paymentsClient.startObserving = { .never }
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
        let id1 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.popFrom(id: id1)))))

        store.send(.main(.settings(.showDrillDown(.supportCenter))))
        snap(appView, caseName: "3 SupportCenter", trait: trait)
        let id2 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.popFrom(id: id2)))))

        store.send(.main(.settings(.showDrillDown(.privacyPolicy))))
        snap(appView, caseName: "4 PrivacyPolicy", trait: trait)
        let id3 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.popFrom(id: id3)))))

        store.send(.main(.settings(.showDrillDown(.eula))))
        snap(appView, caseName: "5 EULA", trait: trait)
        let id4 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.popFrom(id: id4)))))

        store.send(.main(.settings(.showLogs)))
        snap(appView, caseName: "6 Logs Selection", trait: trait)

        let id5 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.element(id: id5, action: .logSelection(.logSelected(.app)))))))
        snap(appView, caseName: "7 App Logs", trait: trait)
        let id5b = store.state.main.settings.path.ids[1]
        store.send(.main(.settings(.path(.popFrom(id: id5b)))))

        let id6 = store.state.main.settings.path.ids.first!
        store.send(.main(.settings(.path(.element(id: id6, action: .logSelection(.logSelected(.wireguard)))))))
        snap(appView, caseName: "8 WireGuard Logs", trait: trait)
    }
}

extension SettingsFeatureSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
            return nil
        }

        let path = FilePath(String(describing: #filePath))
        let suite = path.lastComponent?.stem ?? ""
        return "\(projectDir)/libraries/Features/tvos_app/Tests/tvos_appSnapshotTests/__Snapshots__/\(suite)"
    }
}
