//
//  DependencyContainer.swift
//  ProtonVPN - Created on 09/09/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import UIKit

import Dependencies

import BugReport
import CommonNetworking
import Domain
import Ergonomics
import LegacyCommon
import Review
import Search
import Timer

// FUTURETODO: clean up objects that are possible to re-create if memory warning is received

final class DependencyContainer: Container {
    public static var shared: DependencyContainer = .init()

    // Singletons
    private lazy var navigationService = NavigationService(self)
    private lazy var appSessionManager = AppSessionManagerImplementation(factory: self)
    private lazy var uiAlertService = IosUiAlertService()
    private lazy var iosAlertService = IosAlertService(self)

    // Refreshes app data at predefined time intervals
    private lazy var refreshTimer: AppSessionRefreshTimer = {
        let result = AppSessionRefreshTimerImplementation(
            factory: self,
            refreshIntervals: (
                full: AppConstants.Time.fullServerRefresh,
                loads: AppConstants.Time.serverLoadsRefresh,
                account: AppConstants.Time.userAccountRefresh,
                streaming: AppConstants.Time.streamingInfoRefresh,
                partners: AppConstants.Time.partnersInfoRefresh
            ),
            delegate: self
        )
        return result
    }()

    private lazy var vpnAuthentication: VpnAuthentication = VpnAuthenticationRemoteClient()

    private lazy var planService = CorePlanService(alertService: makeCoreAlertService())

    private lazy var review = {
        @Dependency(\.vpnKeychain) var vpnKeychain
        @Dependency(\.propertiesManager) var propertiesManager
        return Review(
            configuration: ReviewConfiguration(settings: propertiesManager.ratingSettings),
            plan: (try? vpnKeychain.fetchCached().planTitle),
            logger: { log.debug("\($0)", category: .review) }
        )
    }()

    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(self)

    // MARK: - Init

    init() {
        super.init(
            Config(
                os: "iOS",
                openVpnExtensionBundleIdentifier: AppConstants.NetworkExtensions.openVpn,
                wireguardVpnExtensionBundleIdentifier: AppConstants.NetworkExtensions.wireguard
            )
        )

        // Some classes depend on shared container from vpncore directly
        Container.sharedContainer = self
    }

    // MARK: - Overridden factory methods

    // MARK: CoreAlertServiceFactory

    override func makeCoreAlertService() -> CoreAlertService {
        iosAlertService
    }

    // MARK: VpnCredentialsConfiguratorFactoryCreator

    override func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory {
        IOSVpnCredentialsConfiguratorFactory(
            vpnAuthentication: vpnAuthentication
        )
    }

    // MARK: VpnAuthentication

    override func makeVpnAuthentication() -> VpnAuthentication {
        vpnAuthentication
    }

    override func makeUpdateChecker() -> UpdateChecker {
        iOSUpdateManager()
    }
}

extension DependencyContainer: AppSessionRefreshTimerDelegate {
    func canRefreshAccount() -> Bool {
        @Dependency(\.authKeychain) var authKeychain
        return authKeychain.username != nil
    }
}

// MARK: NavigationServiceFactory

extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        navigationService
    }
}

// MARK: SettingsServiceFactory

extension DependencyContainer: SettingsServiceFactory {
    func makeSettingsService() -> SettingsService {
        navigationService
    }
}

// MARK: DynamicBugReportManagerFactory

extension DependencyContainer: DynamicBugReportManagerFactory {
    public func makeDynamicBugReportManager() -> DynamicBugReportManager {
        dynamicBugReportManager
    }
}

// MARK: AppSessionManagerFactory

extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        appSessionManager
    }
}

// MARK: UIAlertServiceFactory

extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        uiAlertService
    }
}

// MARK: AppSessionRefreshTimerFactory

extension DependencyContainer: AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        refreshTimer
    }
}

// MARK: - AppSessionRefresherFactory

extension DependencyContainer: AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher {
        appSessionManager
    }
}

// MARK: LoginServiceFactory

extension DependencyContainer: LoginServiceFactory {
    func makeLoginService() -> LoginService {
        CoreLoginService(factory: self)
    }
}

// MARK: PlanServiceFactory

extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        planService
    }
}

// MARK: OnboardingServiceFactory

extension DependencyContainer: OnboardingServiceFactory {
    func makeOnboardingService() -> OnboardingService {
        OnboardingModuleService(factory: self)
    }
}

// MARK: ReviewFactory

extension DependencyContainer: ReviewFactory {
    func makeReview() -> Review {
        review
    }
}
