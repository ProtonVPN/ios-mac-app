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

class WelcomeFeatureSnapshotTests: BaseTestClass {

    override func setUp() {
        super.setUp()
    }

    func testWelcomeView() {
        let store = Store(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }

        let welcomeView = WelcomeView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        assertSnapshot(of: welcomeView, as: .image(traits: traitDarkMode))
    }

    func testSignInView() {
        let store = Store(initialState: SignInFeature.State(authentication: .waitingForAuthentication(code: .init(selector: "", userCode: "1234ABCD"), remainingAttempts: 0))) {
            SignInFeature()
        }
        let signInView = SignInView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        assertSnapshot(of: signInView, as: .image(traits: traitDarkMode))
    }

    func testCreateAccountView() {
        let store = Store(initialState: WelcomeInfoFeature.State.createAccount) {
            WelcomeInfoFeature()
        }
        let welcomeView = WelcomeInfoView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        assertSnapshot(of: welcomeView, as: .image(traits: traitDarkMode))
    }
}
