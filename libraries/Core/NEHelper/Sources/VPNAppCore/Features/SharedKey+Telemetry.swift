//
//  Created on 26/08/2026 by Max Kupetskyi.
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

import Dependencies
import Domain
import Foundation
import Sharing

// MARK: - Storage key names

let userAccountCreationDateKeyPrefix = "UserAccountCreationDate"
let telemetryUsageDataKeyPrefix = "TelemetryUsageData"
let telemetryCrashReportsKeyPrefix = "TelemetryCrashReports"
let telemetryNeedsReconsentKeyPrefix = "TelemetryNeedsReconsent"

// MARK: - Keys

public extension SharedKey where Self == UserScopedAppStorageKey<Date?> {
    /// The date the signed-in user created their Proton account, as the API reports it.
    static var userAccountCreationDate: Self {
        .date(userAccountCreationDateKeyPrefix)
    }
}

/// The `default` on each of these is required by `@Shared` and never reached. The underlying keys
/// always resolve a value: the stored answer when there is one, ``telemetryDefault(in:username:)`` when the
/// user has not answered, and `false` when nobody is signed in.
public extension SharedKey where Self == UserScopedAppStorageKey<Bool>.Default {
    /// Whether the app may send usage statistics for the signed-in user.
    static var telemetryUsageData: Self {
        Self[TelemetryOptIn.usageData, default: false]
    }

    /// Whether the app may send crash reports for the signed-in user.
    static var telemetryCrashReports: Self {
        Self[TelemetryOptIn.crashReports, default: false]
    }

    /// Whether the app has to ask the signed-in user for their telemetry answer again.
    static var telemetryNeedsReconsent: Self {
        Self[TelemetryOptIn.needsReconsentKey, default: false]
    }
}

// MARK: - Reading the opt-in at the moment it matters

/// The telemetry opt-ins for whoever is signed in right now
public enum TelemetryOptIn {
    static var usageData: UserScopedAppStorageKey<Bool> {
        .telemetryOptIn(telemetryUsageDataKeyPrefix)
    }

    static var crashReports: UserScopedAppStorageKey<Bool> {
        .telemetryOptIn(telemetryCrashReportsKeyPrefix)
    }

    static var needsReconsentKey: UserScopedAppStorageKey<Bool> {
        .flag(telemetryNeedsReconsentKeyPrefix)
    }

    /// Whether the app may send usage statistics.
    public static var sharesUsageData: Bool {
        usageData.currentValue()
    }

    /// Whether the app may send crash reports.
    public static var sharesCrashReports: Bool {
        crashReports.currentValue()
    }

    /// Whether the app has to ask this user for their answer again before it can rely on it.
    public static var needsReconsent: Bool {
        needsReconsentKey.currentValue()
    }

    /// Stores the answer the user just gave, and stops the app asking them again.
    public static func record(sharesUsageData: Bool, sharesCrashReports: Bool) {
        usageData.setCurrentValue(sharesUsageData)
        crashReports.setCurrentValue(sharesCrashReports)
        needsReconsentKey.setCurrentValue(false)
    }
}

// MARK: - Encoding

extension UserScopedAppStorageKey where Value == Bool {
    /// A telemetry opt-in stored under `keyPrefix + username`.
    static func telemetryOptIn(_ keyPrefix: String) -> Self {
        @Dependency(\.authKeychain) var authKeychain
        let username = authKeychain.usernameCachedOrFetched
        return UserScopedAppStorageKey<Bool>(
            baseKey: keyPrefix,
            // No signed-in user means no account to report against.
            valueWhenNoUser: false,
            decode: { store, key in
                storedTelemetryAnswer(in: store, at: key) ?? telemetryDefault(in: store, username: username)
            },
            encode: { value, store, key in
                store.set(String(value), forKey: key)
            }
        )
    }

    /// A per-user flag stored as a native boolean, reading as `false` when absent.
    static func flag(_ keyPrefix: String) -> Self {
        UserScopedAppStorageKey<Bool>(
            baseKey: keyPrefix,
            valueWhenNoUser: false,
            decode: { store, key in store.bool(forKey: key) },
            encode: { value, store, key in store.set(value, forKey: key) }
        )
    }
}

// MARK: - Reading what is on disk

/// The telemetry answer stored at `key`, or `nil` when the user has not answered.
func storedTelemetryAnswer(in store: UserDefaults, at key: String) -> Bool? {
    switch store.object(forKey: key) {
    case let string as String:
        Bool(string)
    case let number as NSNumber:
        number.boolValue
    default:
        nil
    }
}

/// What the app treats a user as having chosen until they answer for themselves.
///
/// Proton started asking during onboarding on 1 August 2023. Accounts created from that day on
/// were asked, so sharing is their starting point. Older accounts were never asked, so they stay
/// out until they say otherwise.
func telemetryDefault(in store: UserDefaults, username: String?) -> Bool {
    guard let username,
          let accountCreatedAt = store.object(forKey: userAccountCreationDateKeyPrefix + username) as? Date
    else {
        return false
    }
    return accountCreatedAt >= DomainConstants.WatershedEvent.telemetrySettingDefaultValue
}
