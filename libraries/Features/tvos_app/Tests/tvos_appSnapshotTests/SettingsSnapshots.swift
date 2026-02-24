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

import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics
@testable import tvos_app

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
final class SettingsFeatureSnapshotTests {
    @Test("Settings snapshots - Light")
    func lightSettings() {
        settings(trait: .light)
    }

    @Test("Settings snapshots - Dark")
    func darkSettings() {
        settings(trait: .dark)
    }

    func settings(trait: UIUserInterfaceStyle) {
        let listState = AppFeature.State(
            main: .init(
                currentTab: .settings,
                mainBackground: .clear
            ),
            networking: .authenticated(.auth(uid: ""))
        )
        let listView = NavigationStack {
            AppView(store: makeStore(state: listState, mainBackground: .clear))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(listView, caseName: "1 List", trait: trait)

        let contactUsState = makeSettingsState(
            path: .settingsDrillDown(.dynamic(.contactUs))
        )
        let contactUsView = NavigationStack {
            AppView(store: makeStore(state: contactUsState, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(contactUsView, caseName: "2 ContactUs", trait: trait)

        let supportCenterState = makeSettingsState(
            path: .settingsDrillDown(.dynamic(.supportCenter))
        )
        let supportCenterView = NavigationStack {
            AppView(store: makeStore(state: supportCenterState, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(supportCenterView, caseName: "3 SupportCenter", trait: trait)

        let privacyPolicyState = makeSettingsState(
            path: .settingsDrillDown(.dynamic(.privacyPolicy))
        )
        let privacyPolicyView = NavigationStack {
            AppView(store: makeStore(state: privacyPolicyState, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(privacyPolicyView, caseName: "4 PrivacyPolicy", trait: trait)

        let eulaState = makeSettingsState(path: .settingsDrillDown(.eula))
        let eulaView = NavigationStack {
            AppView(store: makeStore(state: eulaState, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(eulaView, caseName: "5 EULA", trait: trait)

        let logSelectionState = makeSettingsState(path: .logSelection(.init()))
        let logSelectionView = NavigationStack {
            AppView(store: makeStore(state: logSelectionState, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(logSelectionView, caseName: "6 Logs Selection", trait: trait)

        let logsAppStateLoading = makeSettingsState(path: .logs(.init(logSource: .app, isLoading: true)))
        let logsAppViewLoading = NavigationStack {
            AppView(store: makeStore(state: logsAppStateLoading, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(logsAppViewLoading, caseName: "7 App Logs Loading", trait: trait)

        let logsAppStateLoaded = makeSettingsState(
            path: .logs(.init(logSource: .app, logs: readTestLogs(), isLoading: false))
        )
        let logsAppViewLoaded = NavigationStack {
            AppView(store: makeStore(state: logsAppStateLoaded, mainBackground: .settingsDrillDown))
        }
        .frame(.rect(width: 1920, height: 1080))
        .background(Color(.background, .strong))
        snap(logsAppViewLoaded, caseName: "8 App Logs Loaded", trait: trait)
    }

    // MARK: Private

    private func readTestLogs() -> String {
        let logFile = Bundle.module.url(forResource: "ApplicationLogs_tvOS", withExtension: "log")!
        let contents = try? String(contentsOf: logFile)
        return contents ?? ""
    }
}

private extension SettingsFeatureSnapshotTests {
    func makeSettingsState(
        path: SettingsFeature.Path.State
    ) -> AppFeature.State {
        var settingsState = SettingsFeature.State()
        settingsState.path.append(path)

        return AppFeature.State(
            main: .init(
                currentTab: .settings,
                settings: settingsState,
                mainBackground: .settingsDrillDown
            ),
            networking: .authenticated(.auth(uid: ""))
        )
    }

    func makeStore(
        state: AppFeature.State,
        mainBackground: MainBackground
    ) -> StoreOf<AppFeature> {
        @Shared(.userDisplayName) var userDisplayName: String?
        $userDisplayName.withLock { $0 = "test user" }
        @Shared(.userTier) var userTier: Int?
        $userTier.withLock { $0 = .paidTier }
        @Shared(.mainBackground) var sharedBackground: MainBackground
        $sharedBackground.withLock { $0 = mainBackground }

        return Store(initialState: state) {
            EmptyReducer()
        }
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
