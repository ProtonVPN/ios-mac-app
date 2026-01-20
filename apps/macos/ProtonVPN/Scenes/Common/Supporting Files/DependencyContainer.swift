//
//  DependencyContainer.swift
//  ProtonVPN - Created on 21/08/2019.
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

import AppKit
import Foundation
import NetworkExtension

import BugReport
import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import PMLogger

final class DependencyContainer: Container {
    // Singletons
    private lazy var navigationService = NavigationService(self)

    private lazy var windowService: WindowService = WindowServiceImplementation(factory: self)
    private lazy var vpnAuthentication: VpnAuthentication = VpnAuthenticationManager()

    private lazy var appSessionManager: AppSessionManagerImplementation = .init(factory: self)
    private lazy var macAlertService: MacAlertService = .init(factory: self)

    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(self)

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

    // Manages app updates
    private lazy var updateManager = UpdateManager()

    private lazy var appCertificateRefreshManager = AppCertificateRefreshManagerImplementation(factory: self)

    private lazy var sysexManager = SystemExtensionManager(factory: self)

    override public init() {
        super.init()
        // Some classes depend on shared container from vpncore directly
        Container.sharedContainer = self
    }

    // MARK: - Overridden factory methods

    // MARK: CoreAlertServiceFactory

    override func makeCoreAlertService() -> CoreAlertService {
        macAlertService
    }

    // MARK: VpnCredentialsConfiguratorFactoryCreator

    override func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory {
        MacVpnCredentialsConfiguratorFactory(
            vpnAuthentication: makeVpnAuthentication(),
            appGroup: DomainConstants.AppGroups.main
        )
    }

    // MARK: VpnAuthentication

    override func makeVpnAuthentication() -> VpnAuthentication {
        vpnAuthentication
    }

    // MARK: UpdateManagerFactory

    override func makeUpdateChecker() -> UpdateChecker {
        updateManager
    }
}

extension DependencyContainer: AppSessionRefreshTimerDelegate {
    private func wasRecentlyActive() -> Bool {
        AppDelegate.wasRecentlyActive
    }

    func shouldRefreshLoads() -> Bool {
        wasRecentlyActive()
    }

    func shouldRefreshAccount() -> Bool {
        guard wasRecentlyActive() else { return false }
        @Dependency(\.authKeychain) var authKeychain
        guard authKeychain.username != nil else { return false }
        return true
    }

    func shouldRefreshFull() -> Bool {
        wasRecentlyActive()
    }

    func shouldRefreshPartners() -> Bool {
        wasRecentlyActive()
    }

    func shouldRefreshStreaming() -> Bool {
        wasRecentlyActive()
    }
}

// MARK: NavigationServiceFactory

extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        navigationService
    }
}

// MARK: WindowServiceFactory

extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        windowService
    }
}

// MARK: OsxUiAlertServiceFactory

extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        OsxUiAlertService(factory: self)
    }
}

// MARK: AppSessionManagerFactory

extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        appSessionManager
    }
}

// MARK: NotificationManagerFactory

extension DependencyContainer: NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManagerProtocol {
        NotificationManager(
            appStateManager: makeAppStateManager(),
            appSessionManager: makeAppSessionManager()
        )
    }
}

// MARK: DynamicBugReportManagerFactory

extension DependencyContainer: DynamicBugReportManagerFactory {
    public func makeDynamicBugReportManager() -> DynamicBugReportManager {
        dynamicBugReportManager
    }
}

// MARK: MigrationManagerFactory

extension DependencyContainer: MigrationManagerFactory {
    func makeMigrationManager() -> MigrationManagerProtocol {
        @Dependency(\.appInfo) var appInfo
        let currentVersion = appInfo.bundleShortVersion
        return MigrationManager(currentAppVersion: currentVersion)
    }
}

// MARK: RefreshTimerFactory

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

// MARK: - HeaderViewModelFactory

extension DependencyContainer: HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel {
        HeaderViewModel(factory: self)
    }
}

// MARK: - SystemExtensionManagerFactory

extension DependencyContainer: SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager {
        sysexManager
    }
}

// MARK: AppCertificateRefreshManagerFactory

extension DependencyContainer: AppCertificateRefreshManagerFactory {
    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager {
        appCertificateRefreshManager
    }
}

// MARK: ProtonReachabilityCheckerFactory

extension DependencyContainer: ProtonReachabilityCheckerFactory {
    func makeProtonReachabilityChecker() -> ProtonReachabilityChecker {
        URLSessionProtonReachabilityChecker()
    }
}

// MARK: StatusMenuViewModelFactory

extension DependencyContainer: StatusMenuViewModelFactory {
    func makeStatusMenuViewModel() -> StatusMenuViewModel {
        StatusMenuViewModel(factory: self)
    }
}

// MARK: UpdateManagerFactory

extension DependencyContainer: UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager {
        updateManager
    }
}
