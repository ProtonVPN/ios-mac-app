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

class AppFeatureSnapshotTests: XCTestCase {

    func testApp() {
        let store = Store(initialState: AppFeature.State(networking: .authenticated(.unauth(uid: "")))) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.continuousClock = TestClock()
        }

        let appView = AppView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "1 Welcome")
        store.send(.welcome(.showCreateAccount))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "2 CreateAccount")
        store.send(.welcome(.showSignIn))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "3 SignInRetrievingCode")
        store.send(.welcome(.destination(.presented(.signIn(.codeFetchingFinished(.success(SignInCode(selector: "", userCode: "1234ABCD"))))))))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "4 SignInWithCode")
        store.send(.welcome(.destination(.presented(.signIn(.signInFinished(.failure(.authenticationAttemptsExhausted)))))))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "5 CodeExpired")
        store.send(.welcome(.userTierUpdated(0)))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "6 Upsell")
        store.send(.networking(.startAcquiringSession))
        assertSnapshot(of: appView, as: .image(traits: .darkMode), named: "7 AcquiringSession")
    }
}
