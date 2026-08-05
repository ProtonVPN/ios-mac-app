//
//  AppSessionRefresher.swift
//  vpncore - Created on 2020-09-01.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Foundation
import Persistence
import ProtonCoreServices
import Sharing
import VPNAppCore
import VPNShared

/// Classes that confirm to this protocol can refresh data from API into the app
public protocol AppSessionRefresher: AnyObject {
    func refreshData() async
    func refreshServerLoads() async
    func refreshAccount() async
    func refreshStreamingServices() async
}

public protocol AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher
}

open class AppSessionRefresherImplementation: AppSessionRefresher {
    public var loggedIn = false

    @Dependency(\.vpnApiClient) private var vpnApiClient
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.updateManager) private var updateManager
    @Dependency(\.upsellManager) private var upsellManager
    @Dependency(\.coreAlertService) public var alertService

    private var notificationCenter: NotificationCenter = .default

    private var observation: NotificationToken?

    public init() {
        self.observation = notificationCenter.addObserver(
            for: AppEvent.planChanged.name,
            object: nil,
            handler: { [weak self] in
                self?.userPlanChanged($0)
            }
        )
    }

    public func refreshData() async {
        @Dependency(\.userSettingsClient) var userSettingsClient
        do {
            try await attemptSilentLogIn()
            async let _ = CheckedFeatureFlagsRepository.shared.fetchFlags()

            let userSettings = try await userSettingsClient.fetchUserSettings(authCredentials: authKeychain.fetch())
            @Shared(.userSettings) var sharedUserSettings
            $sharedUserSettings.withLock { $0 = userSettings }
            @Shared(.userInfo) var userInfo
            $userInfo.withLock { $0?.apply(userSettings) }
        } catch {
            log.error("Failed to refresh vpn credentials", category: .app, metadata: ["error": "\(error)"])

            switch error.responseCode {
            case ApiErrorCode.apiVersionBad, ApiErrorCode.appVersionBad:
                presentAppUpdateRequired(error)
            default:
                break // ignore failures
            }
        }
    }

    /// Presents the "app update required" alert when the API rejects the app version.
    ///
    /// The base implementation only shows the informational alert. Platforms override this to
    /// attach the appropriate action (e.g. iOS forces a logout) so the alert presenter itself
    /// stays free of session side effects.
    open func presentAppUpdateRequired(_ error: Error) {
        alertService.push(alert: AppUpdateRequiredAlert(error))
    }

    public func refreshServerLoads() async {
        guard loggedIn else { return }

        @SharedReader(.userLocation) var userLocation
        let lastKnownIp = (userLocation?.location.ip).flatMap { TruncatedIp(ip: $0) }
        do {
            let properties = try await vpnApiClient.loads(lastKnownIp: lastKnownIp)
            let loads = properties.map(\.value)
            @Dependency(\.serverRepository) var serverRepository
            serverRepository.upsert(loads: loads)
            NotificationCenter.default.post(ServerListUpdateNotification(data: .loads), object: nil)
        } catch {
            log.error("RefreshServerLoads error", category: .app, metadata: ["error": "\(error)"])
        }
    }

    public func refreshAccount() async {
        do {
            let credentials = try await vpnApiClient.clientCredentials()
            vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
        } catch {
            log.error("RefreshAccount error", category: .app, metadata: ["error": "\(error)"])
        }
    }

    public func refreshStreamingServices() async {
        guard loggedIn else { return }

        do {
            let streamingResponse = try await vpnApiClient.virtualServices()
            @Shared(.streamingServices) var streamingServices
            $streamingServices.withLock { $0 = streamingResponse.streamingServices }
            @Shared(.streamingResourcesUrl) var streamingResourcesUrl
            $streamingResourcesUrl.withLock { $0 = streamingResponse.resourceBaseURL }
        } catch {
            log.error("RefreshStreamingInfo error", category: .app, metadata: ["error": "\(error)"])
        }
    }

    public func checkIfOSIsSupportedInNextUpdateAndAlertIfNeeded() {
        Task.detached {
            let processInfo = ProcessInfo.processInfo
            let osVersionString = processInfo.operatingSystemVersionString

            let minimumOSVersion = await self.updateManager.minimumVersionRequiredByNextUpdate()

            if processInfo.isOperatingSystemAtLeast(minimumOSVersion) {
                return
            }

            // We only want to alert once per OS update.
            @Shared(.didShowDeprecationWarningForOSVersion) var didShowDeprecationWarningForOSVersion
            guard didShowDeprecationWarningForOSVersion != osVersionString else {
                return
            }

            $didShowDeprecationWarningForOSVersion.withLock { $0 = osVersionString }
            self.alertService.push(alert: UpgradeOperatingSystemAlert(minimumOSVersionRequired: minimumOSVersion))
        }
    }

    /// After user plan changes, feature flags may also change, so we have to reload them
    open func userPlanChanged(_ notification: Notification) {
        Task {
            await refreshData()
        }
        presentWelcomeScreen(notification)
    }

    private func presentWelcomeScreen(_ notification: Notification) {
        guard let info = notification.object as? VpnDowngradeInfo else { return }
        if let plan = WelcomeScreenPlan(info: info) {
            upsellManager.presentWelcome(plan)
        }
    }

    // MARK: - Override

    @MainActor
    open func attemptSilentLogIn() async throws {
        fatalError("This method should be overridden, but it is not")
    }
}

private extension WelcomeScreenPlan {
    init?(info: VpnDowngradeInfo) {
        // Replace hardcoded string with a proper solution VPNAPPL-2142
        if info.to.planName == "bundle2022" {
            self = .unlimited
        } else if info.to.maxTier.isPaid {
            @Dependency(\.serverRepository) var repository
            self = .plus(
                numberOfServers: repository.roundedServerCount,
                numberOfDevices: DomainConstants.maxDeviceCount,
                numberOfCountries: repository.countryCount()
            )
        } else if info.to.maxTier > info.from.maxTier {
            self = .fallback
        } else {
            return nil
        }
    }
}
