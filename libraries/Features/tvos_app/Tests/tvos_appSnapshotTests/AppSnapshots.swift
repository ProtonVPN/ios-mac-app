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
import ModalsServices
import SnapshotTesting
import SwiftUI
import System
import TestingErgonomics
@testable import tvos_app
import XCTest

final class AppFeatureSnapshotTests: XCTestCase {
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
            networking: .authenticated(.auth(uid: ""))
        )
        ) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.continuousClock = TestClock()
            $0.paymentsClient.startObserving = { .never }

            @Shared(.userTier) var userTier: Int?
            $userTier.withLock { $0 = .freeTier }
        }

        let appView = AppView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        snap(appView, caseName: "7 Upsell Loading", trait: trait)

        store.send(.upsell(.finishedLoadingProducts(.success([PlanOptionV2.oneMonth, .oneYear]))))
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
            $0.paymentsClient.startObserving = { .never }
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

extension AppFeatureSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
            return nil
        }

        let path = FilePath(String(describing: #filePath))
        let suite = path.lastComponent?.stem ?? ""
        return "\(projectDir)/libraries/Features/tvos_app/Tests/tvos_appSnapshotTests/__Snapshots__/\(suite)"
    }
}

private extension Locale {
    static let en_US: Self = .init(identifier: "en_US")
}
