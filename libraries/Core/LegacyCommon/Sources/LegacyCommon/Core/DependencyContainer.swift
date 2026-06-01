//
//  Created on 2022-09-08.
//
//  Copyright (c) 2022 Proton AG
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

import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Foundation
import Localization
import NetworkExtension
import PMLogger
import ProtonCoreFeatureFlags
import ProtonCorePushNotifications
import Telemetry
import Timer
import VPNAppCore
import VPNShared

typealias PropertiesToOverride =
    CoreAlertServiceFactory &
    UpdateCheckerFactory &
    VpnAuthenticationFactory

open class Container: PropertiesToOverride {
    @Dependency(\.date) var date

    // Lazy instances - get allocated once, and stay allocated
    @Dependency(\.storage) var storage
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.networking) var networking
    private lazy var profileManager = ProfileManager(self)

    private lazy var pushNotificationService: PushNotificationServiceProtocol = PushNotificationService(apiService: networking.apiService)

    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager(factory: self)
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = .init(factory: self)

    // Should be set in apps to the Container object
    public static var sharedContainer: Container!

    public init() {}

    /// Call this method from `application(didFinishLaunchingWithOptions)` of the app.
    /// It does preparation work needed at the start of the app, but which can't be done in `init` because it's too early.
    public func applicationDidFinishLaunching() {
        Task {
            // We need to initialise the TelemetryService somewhere because no other part of the code uses it directly.
            // TelemetryService listens to notifications and sends telemetry events based on that.
            @Dependency(\.telemetryService) var telemetryService
            @Dependency(\.vpnKeychain) var vpnKeychain

            if !propertiesManager.firstLaunchReported {
                // The app launched for the first time since the last install.
                // Since the telemetry is on by default, there is no way of disabling this event.
                // If we remove the app, we'll still be logged in, but the telemetry settings will be reset to it's default, "On" state.
                try? await telemetryService.onboardingEvent(.firstLaunch)
                propertiesManager.firstLaunchReported = true
            } else if vpnKeychain.userIsLoggedIn { // we flip this bool only on the second launch and only when the user is logged in
                propertiesManager.isSubsequentLaunch = true
            }

            // Start settingsHeartbeat scheduled telemetry report
            telemetryService.startSettingsHeartbeat()
        }
    }

    func shouldHaveOverridden(caller: StaticString = #function) -> Never {
        fatalError("Should have overridden \(caller)")
    }

    // MARK: - Factories to override

    // MARK: CoreAlertService

    open func makeCoreAlertService() -> CoreAlertService {
        shouldHaveOverridden()
    }

    // MARK: VpnAuthentication

    open func makeVpnAuthentication() -> VpnAuthentication {
        shouldHaveOverridden()
    }

    open func makeUpdateChecker() -> UpdateChecker {
        shouldHaveOverridden()
    }
}

// MARK: ProfileManagerFactory

extension Container: ProfileManagerFactory {
    public func makeProfileManager() -> ProfileManager {
        profileManager
    }
}

// MARK: PushNotificationsServiceFactory

extension Container: PushNotificationServiceFactory {
    public func makePushNotificationService() -> ProtonCorePushNotifications.PushNotificationServiceProtocol {
        pushNotificationService
    }
}

// MARK: MaintenanceManagerFactory

extension Container: MaintenanceManagerFactory {
    public func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        maintenanceManager
    }
}

// MARK: MaintenanceManagerHelperFactory

extension Container: MaintenanceManagerHelperFactory {
    public func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        maintenanceManagerHelper
    }
}

// MARK: ProfileStorageFactory

extension Container: ProfileStorageFactory {
    public func makeProfileStorage() -> ProfileStorage {
        ProfileStorage()
    }
}
