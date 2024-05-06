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
@testable import ProtonVPN_TV

final class MainFeatureTests: XCTestCase {

    @MainActor
    func testTabSelection() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.selectTab(.search)) {
            $0.currentTab = .search
        }
        await store.send(.selectTab(.settings)) {
            $0.currentTab = .settings
        }
        await store.send(.selectTab(.home)) {
            $0.currentTab = .home
        }
    }

    @MainActor
    func testSettingsDoesNothing() async {
        let store = TestStore(initialState: MainFeature.State()) {
            MainFeature()
        }
        await store.send(.settings(.contactUs))
    }
}
