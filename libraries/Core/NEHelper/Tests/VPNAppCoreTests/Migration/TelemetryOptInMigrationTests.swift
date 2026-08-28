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
import Testing
import Version
@testable import VPNAppCore
import VPNShared

/// The release each platform first shipped the storage that overwrote answers, and the release
/// before it.
#if os(iOS)
    private let releaseThatOverwroteAnswers = "7.1.0"
    private let releaseBeforeThat = "6.6.5"
    private let releaseWithTheRepair = "8.0.0"
#else
    private let releaseThatOverwroteAnswers = "6.4.0"
    private let releaseBeforeThat = "6.2.0"
    private let releaseWithTheRepair = "7.0.0"
#endif

struct TelemetryOptInMigrationTests {
    private static let username = "test-user"

    /// Runs the telemetry repair as an upgrade from `previousVersion`, and hands back the suite it
    /// ran against so the caller can inspect what it did.
    private func migrate(
        from previousVersion: String,
        signedInAs username: String? = TelemetryOptInMigrationTests.username,
        preparing prepare: (UserDefaults) -> Void
    ) async throws -> UserDefaults {
        let defaults = UserDefaults.inMemory
        defaults.set(previousVersion, forKey: "LastAppVersion")
        prepare(defaults)

        let keychain = MockAuthKeychain()
        if let username {
            keychain.setMockUsername(username)
        }

        try await withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            try await MigrationManagerImplementation(finalVersion: .init(releaseWithTheRepair))
                .checkingTelemetryOptIn()
                .migrate()
        }
        return defaults
    }

    private func needsReconsent(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: telemetryNeedsReconsentKeyPrefix + Self.username)
    }

    // MARK: - The account creation date

    /// The shape most upgrading devices actually hold: version 7 stored a `Date` under a lowercase key.
    @Test("The account creation date version 7 stored is moved to the key the app reads now")
    func restoresAccountCreationDateFromVersion7() async throws {
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set(created, forKey: "userAccountCreationDate")
        }

        #expect(defaults.object(forKey: userAccountCreationDateKeyPrefix + Self.username) as? Date == created)
        #expect(defaults.object(forKey: "userAccountCreationDate") == nil, "The legacy key is cleaned up")
    }

    /// Version 6 stored a `timeIntervalSince1970` double under a capitalised key, which a device that
    /// upgraded straight from 6 still holds.
    @Test("The account creation date version 6 stored is moved to the key the app reads now")
    func restoresAccountCreationDate() async throws {
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let defaults = try await migrate(from: releaseBeforeThat) { defaults in
            defaults.set(created.timeIntervalSince1970, forKey: "UserAccountCreationDate")
        }

        #expect(defaults.object(forKey: userAccountCreationDateKeyPrefix + Self.username) as? Date == created)
        #expect(defaults.object(forKey: "UserAccountCreationDate") == nil, "The legacy key is cleaned up")
    }

    @Test("A device holding both shapes takes the more recent one")
    func prefersTheVersion7Shape() async throws {
        let fromVersion7 = Date(timeIntervalSince1970: 1_750_000_000)
        let fromVersion6 = Date(timeIntervalSince1970: 1_600_000_000)
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set(fromVersion7, forKey: "userAccountCreationDate")
            defaults.set(fromVersion6.timeIntervalSince1970, forKey: "UserAccountCreationDate")
        }

        #expect(defaults.object(forKey: userAccountCreationDateKeyPrefix + Self.username) as? Date == fromVersion7)
    }

    /// The date is the only input to the telemetry default, so destroying it before it can be attributed
    /// would read as "not sharing" for anyone who has never answered.
    @Test("With nobody signed in the date is left where it is")
    func keepsTheDateWhenNobodyIsSignedIn() async throws {
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let defaults = try await migrate(from: releaseThatOverwroteAnswers, signedInAs: nil) { defaults in
            defaults.set(created, forKey: "userAccountCreationDate")
        }

        #expect(defaults.object(forKey: "userAccountCreationDate") as? Date == created)
    }

    @Test("A date already under the new key is left alone")
    func keepsTheNewerAccountCreationDate() async throws {
        let current = Date(timeIntervalSince1970: 1_750_000_000)
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set(current, forKey: userAccountCreationDateKeyPrefix + Self.username)
            let older = Date(timeIntervalSince1970: 1_600_000_000)
            defaults.set(older.timeIntervalSince1970, forKey: "UserAccountCreationDate")
        }

        #expect(defaults.object(forKey: userAccountCreationDateKeyPrefix + Self.username) as? Date == current)
    }

    // MARK: - Who gets asked again

    @Test("A stored no from an affected release is ambiguous, so the user is asked again")
    func asksAgainAfterAnAffectedRelease() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
            defaults.set("false", forKey: telemetryCrashReportsKeyPrefix + Self.username)
        }

        #expect(needsReconsent(in: defaults))
        #expect(
            defaults.string(forKey: telemetryUsageDataKeyPrefix + Self.username) == "false",
            "The stored answer keeps applying, so a real no stays a no until the user says otherwise"
        )
    }

    @Test("A stored yes is unambiguous, because the affected releases only ever wrote no")
    func doesNotAskAgainAfterAYes() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set("true", forKey: telemetryUsageDataKeyPrefix + Self.username)
            defaults.set("true", forKey: telemetryCrashReportsKeyPrefix + Self.username)
        }

        #expect(!needsReconsent(in: defaults))
    }

    @Test("A no on either question is enough to ask again, since both were overwritten alike")
    func asksAgainWhenOnlyOneAnswerIsNo() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set("true", forKey: telemetryUsageDataKeyPrefix + Self.username)
            defaults.set("false", forKey: telemetryCrashReportsKeyPrefix + Self.username)
        }

        #expect(needsReconsent(in: defaults))
    }

    @Test("Upgrading from a release that still had the real answer asks nobody")
    func doesNotAskAfterAnUnaffectedRelease() async throws {
        let defaults = try await migrate(from: releaseBeforeThat) { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
        }

        #expect(!needsReconsent(in: defaults))
    }

    @Test("A user with no stored answer is not asked, because the derived default applies to them")
    func doesNotAskWhenNothingWasStored() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { _ in }

        #expect(!needsReconsent(in: defaults))
    }

    @Test("Every account on the device is considered, not just the one signed in")
    func asksEveryAffectedAccount() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + "other-user")
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
        }

        #expect(defaults.bool(forKey: telemetryNeedsReconsentKeyPrefix + "other-user"))
        #expect(needsReconsent(in: defaults))
    }

    @Test("The very first affected release counts as affected")
    func asksAfterTheFirstAffectedRelease() async throws {
        let firstAffected = Version.platform(iOS: "7.0.0", macOS: "6.3.0")
        let defaults = try await migrate(from: #require(firstAffected).description) { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
        }

        #expect(needsReconsent(in: defaults))
    }

    /// Devices store the version with the build number attached, e.g. `7.1.0+12345.234`, which
    /// semantic versioning ignores when ordering. If that comparison went the other way the whole
    /// repair would quietly skip every real device.
    @Test("The build number attached to a real device's version does not change who gets asked")
    func comparesVersionsIgnoringBuildMetadata() async throws {
        let affected = try await migrate(from: releaseThatOverwroteAnswers + "+12345.234") { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
        }
        #expect(needsReconsent(in: affected))

        let unaffected = try await migrate(from: releaseBeforeThat + "+12345.234") { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix + Self.username)
        }
        #expect(!needsReconsent(in: unaffected))
    }

    @Test("The copy version 7 kept under the bare key, which nothing reads, is cleaned up")
    func removesTheKeyWithNoUsername() async throws {
        let defaults = try await migrate(from: releaseThatOverwroteAnswers) { defaults in
            defaults.set("false", forKey: telemetryUsageDataKeyPrefix)
            defaults.set("false", forKey: telemetryCrashReportsKeyPrefix)
        }

        #expect(defaults.object(forKey: telemetryUsageDataKeyPrefix) == nil)
        #expect(defaults.object(forKey: telemetryCrashReportsKeyPrefix) == nil)
        #expect(defaults.object(forKey: telemetryNeedsReconsentKeyPrefix) == nil, "A bare key identifies nobody to ask")
    }
}
