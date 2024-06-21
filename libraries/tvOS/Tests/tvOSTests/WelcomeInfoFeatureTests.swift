//
//  Created on 21/06/2024.
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

final class WelcomeInfoFeatureTests: XCTestCase {

    @MainActor
    func testCreateAccount() async {
        let store = TestStore(initialState: WelcomeInfoFeature.State.createAccount) {
            WelcomeInfoFeature()
        }
        let model = store.state.model
        XCTAssertNotNil(model)
    }

    @MainActor
    func testFreeUpsell() async {
        let store = TestStore(initialState: WelcomeInfoFeature.State.freeUpsell) {
            WelcomeInfoFeature()
        }
        let model = store.state.model
        XCTAssertNotNil(model)
    }
}
