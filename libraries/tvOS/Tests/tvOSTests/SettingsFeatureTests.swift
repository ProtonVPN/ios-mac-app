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

import XCTest
import ComposableArchitecture
@testable import tvOS

final class SettingsFeatureTests: XCTestCase {

    @MainActor
    func testClearLoginDetails() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.finishSignOut) {
            $0.isLoading = false
            $0.userDisplayName = nil
        }
    }

    @MainActor
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
        await store.receive(\.finishSignOut) {
            $0.isLoading = false
            $0.userDisplayName = nil
        }
    }

    @MainActor
    func testAlertDismiss() async {
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

    @MainActor
    func testContactUsSelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showDrillDown(.contactUs)) {
            $0.destination = .settingsDrillDown(.contactUs)
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @MainActor
    func testReportAnIssueSelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showDrillDown(.supportCenter)) {
            $0.destination = .settingsDrillDown(.supportCenter)
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @MainActor
    func testPrivacyPolicySelected() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
            await store.send(.showDrillDown(.privacyPolicy)) {
            $0.destination = .settingsDrillDown(.privacyPolicy)
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @MainActor
    func testShowProgressView() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.showProgressView) {
            $0.isLoading = true
        }
    }
}
