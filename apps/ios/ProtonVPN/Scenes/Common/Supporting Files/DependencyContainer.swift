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
import CommonNetworking
import LegacyCommon
import BugReport
import Search
import Review
import Timer

// FUTURETODO: clean up objects that are possible to re-create if memory warning is received

final class DependencyContainer: Container {
    
    public static var shared: DependencyContainer = DependencyContainer()
    
    // Singletons
    private lazy var navigationService = NavigationService(self)
    private lazy var wireguardFactory = WireguardProtocolFactory(self, config: config)
    private lazy var windowService = WindowServiceImplementation(window: UIWindow(frame: UIScreen.main.bounds))
    private lazy var appSessionManager = AppSessionManagerImplementation(factory: self)
    private lazy var uiAlertService = IosUiAlertService(windowService: makeWindowService())
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

    private lazy var vpnAuthentication: VpnAuthentication = {
        return VpnAuthenticationRemoteClient(self)
    }()

    private lazy var networkingDelegate: NetworkingDelegate = iOSNetworkingDelegate(alertingService: makeCoreAlertService()) // swiftlint:disable:this weak_delegate
    private lazy var planService = CorePlanService(networking: makeNetworking(), alertService: makeCoreAlertService(), authKeychain: makeAuthKeychainHandle())

    private lazy var searchStorage = SearchModuleStorage()
    private lazy var review = Review(configuration: ReviewConfiguration(settings: makePropertiesManager().ratingSettings), plan: (try? makeVpnKeychain().fetchCached().planTitle), logger: { message in log.debug("\(message)", category: .review) })

    init() {
        let prefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String

        #if TLS_PIN_DISABLE
        let pin = false
        #else
        let pin = true
        #endif

        super.init(
            Config(
                os: "iOS",
                appIdentifierPrefix: prefix,
                appGroup: AppConstants.AppGroups.main,
                accessGroup: "\(prefix)prt.ProtonVPN",
                openVpnExtensionBundleIdentifier: AppConstants.NetworkExtensions.openVpn,
                wireguardVpnExtensionBundleIdentifier: AppConstants.NetworkExtensions.wireguard,
                pinApiEndpoints: pin
            )
        )

        // Some classes depend on shared container from vpncore directly
        Container.sharedContainer = self
    }

    // MARK: - Overridden factory methods

    // MARK: NetworkingDelegate
    override func makeNetworkingDelegate() -> NetworkingDelegate {
        networkingDelegate
    }

    // MARK: CoreAlertServiceFactory
    override func makeCoreAlertService() -> CoreAlertService {
        iosAlertService
    }

    // MARK: WireguardProtocolFactoryCreator
    override func makeWireguardProtocolFactory() -> WireguardProtocolFactory {
        wireguardFactory
    }

    // MARK: VpnCredentialsConfiguratorFactoryCreator
    override func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory {
        IOSVpnCredentialsConfiguratorFactory(propertiesManager: makePropertiesManager(),
                                             vpnKeychain: makeVpnKeychain(),
                                             vpnAuthentication: vpnAuthentication)
    }

    // MARK: VpnAuthentication
    override func makeVpnAuthentication() -> VpnAuthentication {
        vpnAuthentication
    }

    // MARK: LogContentProviderFactory
    override func makeLogContentProvider() -> LogContentProvider {
        let appLogsFolder = makeLogFileManager()
            .getFileUrl(named: AppConstants.Filenames.appLogFilename)
            .deletingLastPathComponent()
        return IOSLogContentProvider(appLogsFolder: appLogsFolder,
                                     appGroup: AppConstants.AppGroups.main,
                                     wireguardProtocolFactory: wireguardFactory)
    }

    override func makeUpdateChecker() -> UpdateChecker {
        iOSUpdateManager()
    }
}

extension DependencyContainer: AppSessionRefreshTimerDelegate {
    func canRefreshAccount() -> Bool {
        makeAuthKeychainHandle().username != nil
    }
}

// MARK: NavigationServiceFactory
extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        return navigationService
    }
}

// MARK: SettingsServiceFactory
extension DependencyContainer: SettingsServiceFactory {
    func makeSettingsService() -> SettingsService {
        return navigationService
    }
}

// MARK: WindowServiceFactory
extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        return windowService
    }
}

// MARK: AppSessionManagerFactory
extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        return appSessionManager
    }
}

// MARK: UIAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return uiAlertService
    }
}

// MARK: AppSessionRefreshTimerFactory
extension DependencyContainer: AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        return refreshTimer
    }
}

// MARK: - AppSessionRefresherFactory
extension DependencyContainer: AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher {
        return appSessionManager
    }
}

// MARK: LoginServiceFactory
extension DependencyContainer: LoginServiceFactory {
    func makeLoginService() -> LoginService {
        return CoreLoginService(factory: self)
    }
}

// MARK: PlanServiceFactory
extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        return planService
    }
}

// MARK: OnboardingServiceFactory
extension DependencyContainer: OnboardingServiceFactory {
    func makeOnboardingService() -> OnboardingService {
        return OnboardingModuleService(factory: self)
    }
}

// MARK: BugReportCreatorFactory
extension DependencyContainer: BugReportCreatorFactory {
    func makeBugReportCreator() -> BugReportCreator {
        return iOSBugReportCreator()
    }
}

// MARK: SearchStorageFactory
extension DependencyContainer: SearchStorageFactory {
    func makeSearchStorage() -> SearchStorage {
        return searchStorage
    }
}

// MARK: ReviewFactory
extension DependencyContainer: ReviewFactory {
    func makeReview() -> Review {
        return review
    }
}
