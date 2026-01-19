//
//  MigrationVersionTest.swift
//  vpncore - Created on 23/07/2020.
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

import XCTest

import Sharing
import Version

@testable import Ergonomics

@MainActor
class MigrationVersionTest: XCTestCase {
    static let sharedKey = "LastAppVersion"

    func testSimpleMigration() async throws {
        var checkValue = 0
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "0.0.0+0.0"

        try await MigrationManagerImplementation(finalVersion: "1.6.0")
            .checking("1.6.1") { @MainActor currentVersion in
                XCTAssertEqual(currentVersion, "0.0.0")
                checkValue += 1
            }.migrate()

        XCTAssertEqual(checkValue, 1)
    }

    func testNoMigrationWhenNotNeeded() async throws {
        var checkValue = 0
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "1.6.0"

        try await MigrationManagerImplementation(finalVersion: "1.6.0")
            .checking("1.5.9") { @MainActor _ in
                checkValue += 1
                XCTFail("This update block should not be run!")
            }.checking("1.6.0") { @MainActor _ in
                checkValue += 1
                XCTFail("This update block should not be run!")
            }.migrate()

        XCTAssertEqual(checkValue, 0)
    }

    func testMigratesOnlyWhatIsNeeded() async throws {
        var checkValue = 0
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "1.6.0"

        try await MigrationManagerImplementation(finalVersion: "1.8.0")
            .checking("1.5.9") { @MainActor _ in
                checkValue += 1
                XCTFail("This update block should not be run!")
            }.checking("1.6.0") { @MainActor _ in
                checkValue += 1
                XCTFail("This update block should not be run!")
            }.checking("1.6.0") { @MainActor _ in
                checkValue += 1
            }.checking("1.7.1") { @MainActor _ in
                checkValue += 1
            }.checking("1.8.0") { @MainActor _ in
                checkValue += 1
            }.migrate()

        XCTAssertEqual(checkValue, 3)
    }

    func testMigrationSavesCurrentAppVersionToProperties() async throws {
        var checkValue = 0
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "0.0.0"

        let currentVersionString = "7.0.0+2804198.2512171751"
        try await MigrationManagerImplementation(finalVersion: .init(currentVersionString)!)
            .checking("4.2.0+396043.230391666") { @MainActor _ in
                checkValue += 1
            }.migrate()

        XCTAssertEqual(checkValue, 1)
        XCTAssertEqual(currentVersionString, lastAppVersion)
    }

    func testMigrationSavesMigratedVersionToPropertiesAfterEachStep() async throws {
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "0.0.0"

        let currentVersionString = "7.0.0+2804198.2512171751"
        try await MigrationManagerImplementation(finalVersion: .init(currentVersionString)!)
            .checking("4.2.0+396043.230391666") { _ in
                // empty step, but should still run
            }.checking("6.9.0+796702.493907328") { @MainActor version in
                XCTAssertEqual("4.2.0+396043.230391666", version)
                XCTAssertEqual("4.2.0+396043.230391666", lastAppVersion)
            }.migrate()

        XCTAssertEqual(currentVersionString, lastAppVersion)
    }

    func testMigrationDoesntSaveVersionToPropertiesAfterError() async throws {
        @Shared(.appStorage(Self.sharedKey)) var lastAppVersion = "1.6.0"

        do {
            let currentVersionString = "7.0.0+2804198.2512171751"
            try await MigrationManagerImplementation(finalVersion: .init(currentVersionString)!)
                .checking("7.0.0") { _ in
                    XCTFail("This step shouldn't run! (Short version numbers are the same)")
                }.checking("4.2.0+396043.230391666") { _ in
                    throw POSIXError(.ENOTSUP) // should cause migration to abort and throw error
                }.checking("6.9.0+796702.493907328") { _ in
                    XCTFail("This update block should not be run!")
                }.migrate()

            XCTFail("Migration should not have succeeded!")
        } catch {
            // Version is not changed because 4.2.0 block failed
            XCTAssertEqual("1.6.0", lastAppVersion)
        }
    }
}

class VersionTests: XCTestCase {
    func testParsesVersion() throws {
        XCTAssertEqual(Version("1.2.3").major, 1)
        XCTAssertEqual(Version("1.2.3").minor, 2)
        XCTAssertEqual(Version("1.2.3").patch, 3)
    }

    func testEquality() throws {
        XCTAssertTrue(Version("1.2.3") > Version("1.2.2"))
        XCTAssertTrue(Version("1.2.3") < Version("2.0.0"))
        XCTAssertTrue(Version("1.2.3") == Version("1.2.3"))
    }

    func testPreRelease() throws {
        XCTAssertTrue(Version("1.2.3-beta") > Version("1.2.2-beta"))
        XCTAssertTrue(Version("1.2.3-beta") < Version("2.0.0-beta"))
        XCTAssertTrue(Version("1.2.3-beta") == Version("1.2.3-beta"))

        XCTAssertTrue(Version("1.2.3") > Version("1.2.3-beta"))
        XCTAssertTrue(Version("1.2.3-beta") < Version("1.2.3"))
        XCTAssertTrue(Version("1.2.3-beta") > Version("1.2.3-alpha"))

        XCTAssertTrue(Version("1.0.0-alpha") < Version("1.0.0-alpha.1"))
        XCTAssertTrue(Version("1.0.0-alpha.1") < Version("1.0.0-alpha.beta"))
        XCTAssertTrue(Version("1.0.0-alpha.beta") < Version("1.0.0-beta"))
        XCTAssertTrue(Version("1.0.0-beta") < Version("1.0.0-beta.2"))
        //  XCTAssertTrue(Version("1.0.0-beta.2") < (Version("1.0.0-beta.11"))) // Doesn't work
        XCTAssertTrue(Version("1.0.0-beta.11") < Version("1.0.0-rc.1"))
        XCTAssertTrue(Version("1.0.0-rc.1") < Version("1.0.0"))
    }
}
