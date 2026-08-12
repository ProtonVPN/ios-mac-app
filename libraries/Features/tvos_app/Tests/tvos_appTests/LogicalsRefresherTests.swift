//
//  Created on 12/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

@testable import CommonNetworking
import ComposableArchitecture
import Domain
import Persistence
@testable import PersistenceTestSupport
@testable import tvos_app
import XCTest

final class LogicalsRefresherTests: XCTestCase {
    let enoughTimePassed: TimeInterval = Date().timeIntervalSince1970 - Constants.Time.fullServerRefresh
    let notEnoughTimePassed: TimeInterval = Date().timeIntervalSince1970 - Constants.Time.fullServerRefresh + 1

    @MainActor
    func testShouldRefreshLogicalsWithEmptyRepository() {
        @SharedReader(.lastLogicalsRefresh) var lastLogicalsRefresh: TimeInterval = notEnoughTimePassed

        withDependencies {
            $0.serverRepository = .empty()
            $0.date = .constant(.distantPast)
        } operation: {
            let sut = LogicalsRefresherProvider().liveValue
            XCTAssertTrue(sut.shouldRefreshLogicals())
        }
    }

    @MainActor
    func testShouldRefreshLogicalsWithTimeInterval() {
        @SharedReader(.lastLogicalsRefresh) var lastLogicalsRefresh: TimeInterval = enoughTimePassed

        withDependencies {
            $0.serverRepository = .notEmpty()
            $0.date = .constant(.now)
        } operation: {
            let sut = LogicalsRefresherProvider().liveValue
            XCTAssertTrue(sut.shouldRefreshLogicals())
        }
    }

    @MainActor
    func testShouldNotRefreshLogicals() {
        @SharedReader(.lastLogicalsRefresh) var lastLogicalsRefresh: TimeInterval = notEnoughTimePassed

        withDependencies {
            $0.serverRepository = .notEmpty()
            $0.serverRepository.getMetadata = { _ in "en" }
            $0.date = .constant(.distantPast)
            $0.appLanguage = { "en" }
        } operation: {
            let sut = LogicalsRefresherProvider().liveValue
            XCTAssertFalse(sut.shouldRefreshLogicals())
        }
    }

    @MainActor
    func testShouldRefreshLogicalsAfterLanguageChange() {
        @SharedReader(.lastLogicalsRefresh) var lastLogicalsRefresh: TimeInterval = notEnoughTimePassed

        withDependencies {
            $0.serverRepository = .notEmpty()
            $0.serverRepository.getMetadata = { _ in "fr" }
            $0.date = .constant(.distantPast)
            $0.appLanguage = { "en" }
        } operation: {
            let sut = LogicalsRefresherProvider().liveValue
            XCTAssertTrue(sut.shouldRefreshLogicals())
        }
    }

    @MainActor
    func testRefreshLogicals() async throws {
        @SharedReader(.lastLogicalsRefresh) var lastLogicalsRefresh: TimeInterval = enoughTimePassed

        var upserted: [VPNServer] = []
        var stampedLanguages: [DatabaseMetadata.Key: String] = [:]

        try await withDependencies {
            $0.serverRepository.upsertServers = { upserted = $0 }
            $0.serverRepository.setMetadata = { key, value in stampedLanguages[key] = value }
            $0.date = .constant(.distantPast)
            $0.appLanguage = { "fr" }
            $0.logicalsClient.fetchLogicals = { _, _ in [.mock] }
            $0.userLocationService = .testValue
            $0.locationClient = .testValue
        } operation: {
            let sut = LogicalsRefresherProvider().liveValue
            try await sut.refreshLogicals()
            XCTAssertEqual(upserted, [.mock])
            XCTAssertEqual(stampedLanguages, [.translationsLanguage: "fr"])
        }
    }
}
