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

final class AppFeatureSnapshotTests: XCTestCase {
    static let precision: Float = 0.999
    static let perceptualPrecision: Float = 0.999

    func snap<T: View>(_ view: T, caseName: String, trait: UIUserInterfaceStyle) {
        assertSnapshot(
            of: view,
            as: .image(
                precision: Self.precision,
                perceptualPrecision: Self.perceptualPrecision,
                traits: trait.collection
            ),
            testName: "\(caseName) \(trait.name)"
        )
    }

    func testLightApp() {
        app(trait: .light)
        upsell(trait: .light)
    }

    func testDarkApp() {
        app(trait: .dark)
        upsell(trait: .dark)
    }

    func upsell(trait: UIUserInterfaceStyle) {
        let store = Store(initialState: AppFeature.State(
            welcome: .init(destination: .upsell(.loading)),
            networking: .authenticated(.auth(uid: "")))
        ) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.continuousClock = TestClock()
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { [ ] },
                attemptPurchase: { _ in .purchaseCancelled }
            )

            @Shared(.userTier) var userTier: Int?
            $userTier.withLock { $0 = .freeTier }
        }

        let appView = AppView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        snap(appView, caseName: "7 Upsell Loading", trait: trait)

        store.send(.upsell(.finishedLoadingProducts(.success([
            PlanIAPTuple(
                planOption: .init(
                    duration: .oneMonth, price: .init(amount: 2, currency: "USD", locale: .en_US)
                ),
                iap: .freePlan
            ),
            PlanIAPTuple(
                planOption: .init(
                    duration: .oneYear, price: .init(amount: 12, currency: "USD", locale: .en_US)
                ),
                iap: .freePlan
            )
        ]))))
        snap(appView, caseName: "8 Upsell Loaded", trait: trait)
    }

    func app(trait: UIUserInterfaceStyle) {
        let store = Store(initialState: AppFeature.State(
            networking: .authenticated(.unauth(uid: "")))
        ) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.continuousClock = TestClock()
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { [ ] },
                attemptPurchase: { _ in .purchaseCancelled }
            )
        }

        let appView = AppView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        snap(appView, caseName: "1 Welcome", trait: trait)
        store.send(.welcome(.showCreateAccount))
        snap(appView, caseName: "2 CreateAccount", trait: trait)
        store.send(.welcome(.showSignIn))
        snap(appView, caseName: "3 SignInRetrievingCode", trait: trait)
        store.send(.welcome(.destination(.presented(.signIn(.codeFetchingFinished(.success(SignInCode(selector: "", userCode: "1234ABCD"))))))))
        snap(appView, caseName: "4 SignInWithCode", trait: trait)
        store.send(.welcome(.destination(.presented(.signIn(.signInFinished(.failure(.authenticationAttemptsExhausted)))))))
        snap(appView, caseName: "5 CodeExpired", trait: trait)

        store.send(.networking(.startAcquiringSession))
        snap(appView, caseName: "6 AcquiringSession", trait: trait)
    }
}

fileprivate extension Locale {
    static let en_US: Self = .init(identifier: "en_US")
}
