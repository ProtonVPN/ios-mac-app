//
//  Created on 02/07/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Sharing

// Keys migrated off the legacy `PropertiesManager`. Each reuses the exact UserDefaults key and
// on-disk representation the legacy property used, so existing user data is read transparently.

// MARK: - Bool

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// Whether this is a subsequent (non-first) app launch.
    static var isSubsequentLaunch: Self {
        Self[.appStorage("isSubsequentLaunch"), default: false]
    }

    /// Whether the first-launch report has already been sent.
    static var firstLaunchReported: Self {
        Self[.appStorage("firstLaunchReported"), default: false]
    }

    /// Whether the user has connected at least once (used for first-time-connect behaviour).
    /// Legacy key: `ConnectOnDemand`.
    static var hasConnected: Self {
        Self[.appStorage("ConnectOnDemand"), default: false]
    }

    /// Whether the "What's New" modal should still be shown.
    static var showWhatsNewModal: Self {
        Self[.appStorage("ShowWhatsNewModal_Redesign_Phase_1"), default: true]
    }

    /// Whether auto-connect on launch is enabled (the global flag; the profile is stored per-user).
    static var autoConnect: Self {
        Self[.appStorage("AutoConnect"), default: false]
    }

    #if os(macOS)
        /// Whether the macOS system extension must be force-upgraded.
        static var forceExtensionUpgrade: Self {
            Self[.appStorage("ForceExtensionUpgrade"), default: false]
        }
    #endif
}

// MARK: - String?

public extension SharedKey where Self == AppStorageKey<String?>.Default {
    /// The last email address entered in the bug report form. Legacy key: `LastBugReportEmail`.
    static var reportBugEmail: Self {
        Self[.appStorage("LastBugReportEmail"), default: nil]
    }

    /// The custom API endpoint (development builds). Legacy key: `ApiEndpoint`.
    static var apiEndpoint: Self {
        Self[.appStorage("ApiEndpoint"), default: nil]
    }

    /// The base URL for streaming service icons.
    static var streamingResourcesUrl: Self {
        Self[.appStorage("streamingResourcesUrl"), default: nil]
    }

    /// The OS version for which the deprecation warning was already shown.
    static var didShowDeprecationWarningForOSVersion: Self {
        Self[.appStorage("DidShowDeprecationWarningForOSVersion"), default: nil]
    }

    /// The Atlas environment secret (development builds). Legacy key: `AtlasSecret`.
    static var atlasSecret: Self {
        Self[.appStorage("AtlasSecret"), default: nil]
    }

    /// The URL used to fetch the Atlas secret (development builds). Legacy key: `AtlasSecretFetchURL`.
    static var atlasSecretFetchURLString: Self {
        Self[.appStorage("AtlasSecretFetchURL"), default: nil]
    }
}

// MARK: - Int

public extension SharedKey where Self == AppStorageKey<Int>.Default {
    /// The maintenance server refresh interval, in minutes. Legacy key:
    /// `MaintenanceServerRefreshIntereval` (default `DomainConstants.Maintenance.defaultMaintenanceCheckTime`).
    static var maintenanceServerRefreshIntereval: Self {
        Self[
            .appStorage("MaintenanceServerRefreshIntereval"),
            default: DomainConstants.Maintenance.defaultMaintenanceCheckTime
        ]
    }
}

// MARK: - JSON-encoded Codable

public extension SharedKey where Self == JSONAppStorageKey<UserLocation?> {
    /// The user's IP location (outside of the VPN). Legacy key: `UserLocation` (JSON).
    ///
    /// Observe changes via `$userLocation.publisher` — this replaces the legacy `AppEvent.userIp`
    /// notification the property used to post on every write.
    static var userLocation: Self {
        .json("UserLocation")
    }
}

public extension SharedKey where Self == JSONAppStorageKey<[String: Bool]?> {
    /// Manual feature-flag overrides (development builds). Legacy key: `FeatureFlagOverrides` (JSON).
    static var featureFlagOverrides: Self {
        .json("FeatureFlagOverrides")
    }
}

public extension SharedKey where Self == JSONAppStorageKey<[String: String]?> {
    /// Manual local-value overrides (development builds). Legacy key: `LocalValuesOverrides` (JSON).
    static var localValuesOverrides: Self {
        .json("LocalValuesOverrides")
    }
}
