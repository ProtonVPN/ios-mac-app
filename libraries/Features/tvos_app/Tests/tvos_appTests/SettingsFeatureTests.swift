//
//  Created on 30/04/2024.
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
import Testing
@testable import tvos_app

@MainActor
struct SettingsFeatureTests {
    @Test
    func testSignOut() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.signOutSelected) {
            $0.alert = SettingsFeature.signOutAlert
        }
        await store.send(.alert(.presented(.signOut))) {
            $0.alert = nil
            $0.isLoading = true
        }
    }

    @Test
    func alertDismiss() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.signOutSelected) {
            $0.alert = SettingsFeature.signOutAlert
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @Test
    func eULASelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showDrillDown(.eula)) {
            $0.path.append(.settingsDrillDown(.eula))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
        let id = store.state.path.ids.first!
        await store.send(.path(.element(id: id, action: .settingsDrillDown(.onExitCommand)))) {
            $0.$mainBackground.withLock { $0 = .clear }
        }
        await store.receive(\.path.popFrom) {
            $0.path = .init()
        }
    }

    @Test
    func contactUsSelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showDrillDown(.contactUs)) {
            $0.path.append(.settingsDrillDown(.dynamic(.contactUs)))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
        let id = store.state.path.ids.first!
        await store.send(.path(.element(id: id, action: .settingsDrillDown(.onExitCommand)))) {
            $0.$mainBackground.withLock { $0 = .clear }
        }
        await store.receive(\.path.popFrom) {
            $0.path = .init()
        }
    }

    @Test
    func reportAnIssueSelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showReportIssue) {
            $0.path.append(.reportIssue(.init()))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
    }

    @Test
    func privacyPolicySelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showDrillDown(.privacyPolicy)) {
            $0.path.append(.settingsDrillDown(.dynamic(.privacyPolicy)))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
        let id = store.state.path.ids.first!
        await store.send(.path(.element(id: id, action: .settingsDrillDown(.onExitCommand)))) {
            $0.$mainBackground.withLock { $0 = .clear }
        }
        await store.receive(\.path.popFrom) {
            $0.path = .init()
        }
    }

    @Test
    func testShowProgressView() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showProgressView) {
            $0.isLoading = true
        }
    }

    @Test
    func showLogsPushesLogSelection() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showLogs) {
            $0.path.append(.logSelection(.init()))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
    }

    @Test
    func selectingLogSourcePushesLogsView() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showLogs) {
            $0.path.append(.logSelection(.init()))
            $0.$mainBackground.withLock { $0 = .settingsDrillDown }
        }
        let id = store.state.path.ids.first!
        await store.send(.path(.element(id: id, action: .logSelection(.logSelected(.wireguard))))) {
            $0.path.append(.logs(.init(logSource: .wireguard)))
        }
    }
}
