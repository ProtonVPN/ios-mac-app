//
//  Created on 30/07/2024.
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
import Dependencies
import Domain
import Home
import LegacyCommon
import Payments
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import UIKit
import VPNAppCore

enum HomeFeatureCreator {
    static func loadInitialState() -> HomeFeature.State {
        // Seed the in-memory default-connection preference from its persisted value.
        @Shared(.defaultConnectionPreference) var defaultConnectionPreference
        @SharedReader(.storedDefaultConnectionPreference) var storedPreference
        $defaultConnectionPreference.withLock { $0 = storedPreference ?? .fastest }

        return .init()
    }

    static func homeViewController() -> UINavigationController {
        let homeStore = StoreOf<HomeFeature>(initialState: loadInitialState()) {
            log.info("Creating HomeFeature", category: .app)
            return HomeFeature()
        } withDependencies: {
            $0.openCredentiallessSignUp = {
                let navService = DependencyContainer.shared.makeNavigationService()
                navService.presentSignUp(over: navService.tabBarController, flow: .credentiallessUpsell)
            }
        }

        let hostingController = UIHostingController(rootView: HomeView(store: homeStore))
        hostingController.tabBarItem = UITabBarItem(title: Localizable.homeTab, image: IconProvider.houseFilled, tag: 0)

        // Those should be called once
        homeStore.send(.onStart)
        homeStore.send(.sharedProperties(.listen))
        homeStore.send(.map(.observeConnectionState))

        // Embed a UINavigationController to prevent layout and sizing issues that arise when using NavigationStack directly within a UIHostingController.
        let navigationController = UINavigationController(rootViewController: hostingController)
        navigationController.additionalSafeAreaInsets = .zero
        navigationController.navigationBar.isTranslucent = true

        return navigationController
    }
}
