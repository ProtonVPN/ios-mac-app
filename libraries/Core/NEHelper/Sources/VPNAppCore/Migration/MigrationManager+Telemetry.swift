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
import Ergonomics
import Foundation
import Sharing
import Version

/// The keys the two releases before this one kept the date under, newest first.
///
/// Version 7 wrote a `Date` under a single lowercase `userAccountCreationDate`. Version 6 wrote a
/// `timeIntervalSince1970` double under a capitalised `UserAccountCreationDate`, which is the same string
/// the per-user key now uses as a prefix, so removing it by exact name cannot touch a per-user entry.
/// A device that went 6 to 7 to here can hold both.
private let legacyUserAccountCreationDateKeys = ["userAccountCreationDate", userAccountCreationDateKeyPrefix]

/// The first release whose telemetry storage wrote its own fallback answer over the user's.
///
/// iOS 7.0.0 and macOS 6.3.0 both read the opt-in as a type neither the app nor its predecessors
/// had written, and the read path persisted the fallback it returned. tvOS never reported
/// telemetry, so it has nothing to repair.
private let firstReleaseThatOverwroteAnswers: Version? = .platform(iOS: "7.0.0", macOS: "6.3.0")

extension MigrationManager {
    /// restores the account creation date under the key the app now reads, and it marks users
    /// whose stored telemetry answer the app wrote for them so the app asks them again.
    func checkingTelemetryOptIn() -> Self {
        checking(.platform(iOS: "8.0.0", macOS: "7.0.0", tvOS: nil)) { previous in
            @Dependency(\.defaultAppStorage) var defaults

            @Dependency(\.authKeychain) var authKeychain
            restoreAccountCreationDate(in: defaults, username: authKeychain.usernameCachedOrFetched)

            guard let firstReleaseThatOverwroteAnswers,
                  previous >= firstReleaseThatOverwroteAnswers
            else {
                // This device upgraded straight from a release that still had the user's real
                // answer, so what is on disk can be trusted.
                return
            }
            markUsersWhoseAnswerWasOverwritten(in: defaults, previous: previous)
        }
    }
}

/// Copies the account creation date from wherever the release before this one left it to the key the app
/// reads now.
private func restoreAccountCreationDate(in defaults: UserDefaults, username: String?) {
    // Nobody to attribute it to yet. The keychain can be unreadable this early, and a legacy entry is the
    // only copy of the date, so it is left for a run that can place it.
    guard let username else { return }

    // Removed only once there is somewhere for it to have gone, which is either this copy or a date the
    // user already had.
    defer {
        for legacyKey in legacyUserAccountCreationDateKeys {
            defaults.removeObject(forKey: legacyKey)
        }
    }

    // A date already recorded for this user is at least as fresh as a legacy one.
    let key = userAccountCreationDateKeyPrefix + username
    guard defaults.object(forKey: key) == nil,
          let legacy = legacyAccountCreationDate(in: defaults)
    else {
        return
    }

    defaults.set(legacy, forKey: key)
    log.info("Restored the account creation date for telemetry", category: .persistence)
}

/// Reads the date in whichever shape it was left in, preferring the more recent.
private func legacyAccountCreationDate(in defaults: UserDefaults) -> Date? {
    if let date = defaults.object(forKey: legacyUserAccountCreationDateKeys[0]) as? Date {
        return date
    }
    if let secondsSince1970 = defaults.object(forKey: legacyUserAccountCreationDateKeys[1]) as? Double {
        return Date(timeIntervalSince1970: secondsSince1970)
    }
    return nil
}

private func markUsersWhoseAnswerWasOverwritten(in defaults: UserDefaults, previous: Version) {
    var flagged = 0

    for username in usernamesWithStoredTelemetryAnswers(in: defaults) {
        let sharesUsageData = storedTelemetryAnswer(in: defaults, at: telemetryUsageDataKeyPrefix + username)
        let sharesCrashReports = storedTelemetryAnswer(in: defaults, at: telemetryCrashReportsKeyPrefix + username)

        // Only `false` is ambiguous. The affected releases never wrote `true`, so a stored `true`
        // is the user's own answer.
        guard sharesUsageData == false || sharesCrashReports == false else { continue }

        defaults.set(true, forKey: telemetryNeedsReconsentKeyPrefix + username)
        flagged += 1
    }

    defaults.removeObject(forKey: telemetryUsageDataKeyPrefix)
    defaults.removeObject(forKey: telemetryCrashReportsKeyPrefix)

    log.info(
        "Telemetry answers may have been overwritten, asking again",
        category: .persistence,
        metadata: ["previousVersion": "\(previous)", "usersToAsk": "\(flagged)"]
    )
}

/// The usernames that have a telemetry answer stored against them, from either opt-in key.
private func usernamesWithStoredTelemetryAnswers(in defaults: UserDefaults) -> Set<String> {
    let keys = defaults.dictionaryRepresentation().keys
    let usernames = keys.flatMap { key -> [String] in
        [telemetryUsageDataKeyPrefix, telemetryCrashReportsKeyPrefix]
            .filter { key.hasPrefix($0) }
            .map { String(key.dropFirst($0.count)) }
    }
    // The bare prefix carries no username, so it identifies nobody to ask.
    return Set(usernames.filter { !$0.isEmpty })
}
