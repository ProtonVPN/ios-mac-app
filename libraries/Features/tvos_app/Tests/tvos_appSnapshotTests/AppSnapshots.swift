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
import Testing
import TestingErgonomics
@testable import tvos_app

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
final class AppFeatureSnapshotTests {
    @Test("App snapshots - Light")
    func lightApp() {
        app(trait: .light)
        upsell(trait: .light)
    }

    @Test("App snapshots - Dark")
    func darkApp() {
        app(trait: .dark)
        upsell(trait: .dark)
    }

    func upsell(trait: UIUserInterfaceStyle) {
        let loadingState = AppFeature.State(upsell: .loading, networking: .authenticated(.auth(uid: "")))
        let loadingStore = makeStore(state: loadingState, userTier: .freeTier)
        let loadingView = AppView(store: loadingStore)
            .frame(.rect(width: 1920, height: 1080))
        snap(loadingView, caseName: "7 Upsell Loading", trait: trait)

        let loadedState = AppFeature.State(
            upsell: .loaded(planOptions: [PlanOptionV2.oneYear, .oneMonth], purchaseInProgress: false),
            networking: .authenticated(.auth(uid: ""))
        )
        let loadedStore = makeStore(state: loadedState, userTier: .freeTier)
        let loadedView = AppView(store: loadedStore)
            .frame(.rect(width: 1920, height: 1080))
        snap(loadedView, caseName: "8 Upsell Loaded", trait: trait)
    }

    func app(trait: UIUserInterfaceStyle) {
        let welcomeState = AppFeature.State(networking: .authenticated(.unauth(uid: "")))
        let welcomeView = AppView(store: makeStore(state: welcomeState))
            .frame(.rect(width: 1920, height: 1080))
        snap(welcomeView, caseName: "1 Welcome", trait: trait)

        let createAccountState = AppFeature.State(
            welcome: .init(destination: .welcomeInfo(.createAccount)),
            networking: .authenticated(.unauth(uid: ""))
        )
        let createAccountView = AppView(store: makeStore(state: createAccountState))
            .frame(.rect(width: 1920, height: 1080))
        snap(createAccountView, caseName: "2 CreateAccount", trait: trait)

        let signInLoadingState = AppFeature.State(
            welcome: .init(destination: .signIn(.init(authentication: .loadingSignInCode))),
            networking: .authenticated(.unauth(uid: ""))
        )
        let signInLoadingView = AppView(store: makeStore(state: signInLoadingState))
            .frame(.rect(width: 1920, height: 1080))
        snap(signInLoadingView, caseName: "3 SignInRetrievingCode", trait: trait)

        let signInWithCodeState = AppFeature.State(
            welcome: .init(destination: .signIn(.init(
                authentication: .waitingForAuthentication(
                    code: SignInCode(selector: "", userCode: "1234ABCD"),
                    remainingAttempts: 1
                )
            ))),
            networking: .authenticated(.unauth(uid: ""))
        )
        let signInWithCodeView = AppView(store: makeStore(state: signInWithCodeState))
            .frame(.rect(width: 1920, height: 1080))
        snap(signInWithCodeView, caseName: "4 SignInWithCode", trait: trait)

        let codeExpiredState = AppFeature.State(
            welcome: .init(destination: .codeExpired(.init())),
            networking: .authenticated(.unauth(uid: ""))
        )
        let codeExpiredView = AppView(store: makeStore(state: codeExpiredState))
            .frame(.rect(width: 1920, height: 1080))
        snap(codeExpiredView, caseName: "5 CodeExpired", trait: trait)

        let acquiringSessionState = AppFeature.State(networking: .acquiringSession)
        let acquiringSessionView = AppView(store: makeStore(state: acquiringSessionState))
            .frame(.rect(width: 1920, height: 1080))
        snap(acquiringSessionView, caseName: "6 AcquiringSession", trait: trait)
    }
}

private extension AppFeatureSnapshotTests {
    func makeStore(
        state: AppFeature.State,
        userTier: Int? = nil
    ) -> StoreOf<AppFeature> {
        if let userTier {
            @Shared(.userTier) var sharedUserTier: Int?
            $sharedUserTier.withLock { $0 = userTier }
        }
        return Store(initialState: state) {
            EmptyReducer()
        }
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
