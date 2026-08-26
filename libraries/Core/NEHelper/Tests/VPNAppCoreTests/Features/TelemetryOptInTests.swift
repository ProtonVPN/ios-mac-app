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
import Testing
@testable import VPNAppCore
import VPNShared

/// The 1 August 2023 watershed either side, so the derived default is exercised both ways.
private let accountCreatedBeforeProtonAsked = Date(timeIntervalSince1970: 1_600_000_000)
private let accountCreatedAfterProtonAsked = Date(timeIntervalSince1970: 1_750_000_000)

struct TelemetryOptInTests {
    private static let username = "test-user"
    private static let usageDataKey = telemetryUsageDataKeyPrefix + username

    /// Runs `body` with a fresh in-memory suite and a keychain reporting `username` (pass `nil` for
    /// the logged-out state).
    private func withStorage<T>(
        username: String? = TelemetryOptInTests.username,
        accountCreatedAt: Date? = accountCreatedAfterProtonAsked,
        _ body: (UserDefaults) throws -> T
    ) rethrows -> T {
        let defaults = UserDefaults.inMemory
        // The date is stored per user, so with nobody signed in there is nowhere to put it.
        if let accountCreatedAt, let username {
            defaults.set(accountCreatedAt, forKey: userAccountCreationDateKeyPrefix + username)
        }
        let keychain = MockAuthKeychain()
        if let username {
            keychain.setMockUsername(username)
        }
        return try withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            try body(defaults)
        }
    }

    // MARK: - Reading answers the app has already written

    @Test("The string form version 6 wrote is read back as the user's answer")
    func readsStringAnswer() {
        for (stored, expected) in [("true", true), ("false", false)] {
            withStorage { defaults in
                defaults.set(stored, forKey: Self.usageDataKey)
                #expect(TelemetryOptIn.sharesUsageData == expected)
            }
        }
    }

    @Test("The boolean form written before version 6 is still read as the user's answer")
    func readsLegacyBooleanAnswer() {
        withStorage { defaults in
            defaults.set(true, forKey: Self.usageDataKey)
            #expect(TelemetryOptIn.sharesUsageData, "A legacy boolean opt-in keeps reporting")
        }
    }

    @Test("Reading leaves the stored answer alone")
    func readingIsNotDestructive() {
        withStorage { defaults in
            defaults.set(true, forKey: Self.usageDataKey)
            _ = TelemetryOptIn.sharesUsageData
            #expect(
                defaults.object(forKey: Self.usageDataKey) as? Bool == true,
                "Reading used to overwrite the answer with the app's own fallback"
            )
        }
    }

    // MARK: - Users who have not answered

    @Test("An account created after Proton started asking shares by default")
    func newAccountDefaultsToSharing() {
        withStorage(accountCreatedAt: accountCreatedAfterProtonAsked) { _ in
            #expect(TelemetryOptIn.sharesUsageData)
            #expect(TelemetryOptIn.sharesCrashReports)
        }
    }

    @Test("An account that predates Proton asking stays out by default")
    func oldAccountDefaultsToNotSharing() {
        withStorage(accountCreatedAt: accountCreatedBeforeProtonAsked) { _ in
            #expect(!TelemetryOptIn.sharesUsageData)
        }
    }

    @Test("An unknown account creation date stays out by default")
    func unknownAccountAgeDefaultsToNotSharing() {
        withStorage(accountCreatedAt: nil) { _ in
            #expect(!TelemetryOptIn.sharesUsageData)
        }
    }

    @Test("The derived default is not written to disk, so it can still be re-derived")
    func derivedDefaultIsNotPersisted() {
        withStorage { defaults in
            #expect(TelemetryOptIn.sharesUsageData)
            #expect(
                defaults.object(forKey: Self.usageDataKey) == nil,
                "Persisting the derived default is what made the original loss unrecoverable"
            )
        }
    }

    // MARK: - No signed-in user

    @Test("Nothing is reported while nobody is signed in")
    func staysOutWhileSignedOut() {
        withStorage(username: nil) { _ in
            #expect(!TelemetryOptIn.sharesUsageData)
        }
    }

    @Test("An answer is read for whoever is signed in at the time, not at launch")
    func readsTheAnswerOfTheCurrentUser() {
        let defaults = UserDefaults.inMemory
        defaults.set(accountCreatedAfterProtonAsked, forKey: userAccountCreationDateKeyPrefix + "late-arrival")
        let keychain = MockAuthKeychain()

        withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            #expect(!TelemetryOptIn.sharesUsageData, "Nobody is signed in yet")

            keychain.setMockUsername("late-arrival")
            TelemetryOptIn.record(sharesUsageData: true, sharesCrashReports: true)

            #expect(
                TelemetryOptIn.sharesUsageData,
                "A reporter built before sign-in used to keep answering for nobody"
            )
        }
    }

    // MARK: - Recording an answer

    @Test("Recording an answer stores it in the form older versions can read")
    func recordsAnswerAsString() {
        withStorage { defaults in
            TelemetryOptIn.record(sharesUsageData: true, sharesCrashReports: false)

            #expect(defaults.object(forKey: Self.usageDataKey) as? String == "true")
            #expect(
                defaults.object(forKey: telemetryCrashReportsKeyPrefix + Self.username) as? String == "false"
            )
            #expect(TelemetryOptIn.sharesUsageData)
            #expect(!TelemetryOptIn.sharesCrashReports)
        }
    }

    @Test("Recording an answer stops the app asking again")
    func recordingClearsTheRequestToAskAgain() {
        withStorage { defaults in
            defaults.set(true, forKey: telemetryNeedsReconsentKeyPrefix + Self.username)
            #expect(TelemetryOptIn.needsReconsent)

            TelemetryOptIn.record(sharesUsageData: false, sharesCrashReports: false)

            #expect(!TelemetryOptIn.needsReconsent)
        }
    }
}
