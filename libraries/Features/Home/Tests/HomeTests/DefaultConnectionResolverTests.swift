//
//  Created on 07/12/2024.
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

import Collections
@testable import ConnectionInventory
import Dependencies
@testable import Domain
import Foundation
@testable import HomeShared
import XCTest

final class DefaultConnectionResolverTests: XCTestCase {
    typealias Sut = DefaultConnectionResolverImplementation

    // MARK: ConnectionSpec Resolving

    func testResolverReturnsMostRecentConnectionWhenPreferenceIsMostRecent() {
        let mostRecentConnection = ConnectionSpec.franceWithP2P.recent(with: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)

        let recents: OrderedSet<RecentConnection> = [mostRecentConnection, olderRecentConnection]
        XCTAssertEqual(recents.mostRecent, mostRecentConnection) // sanity check

        let resolvedSpec = Sut.connectionSpec(for: .mostRecent, recents: recents, secureCore: false)
        XCTAssertEqual(resolvedSpec, mostRecentConnection.connection)
    }

    func testResolverReturnsSpecificRecentConnectionWhenPrefenceIsSpecific() {
        let resolvedSpec = Sut.connectionSpec(for: .recent(.poland), recents: [], secureCore: false)
        XCTAssertEqual(resolvedSpec, .poland)
    }

    func testResolverReturnsSecureCoreFastestWhenPrefenceIsFastestAndSecureCoreIsOn() {
        let resolvedSpec = Sut.connectionSpec(for: .fastest, recents: [], secureCore: true)
        XCTAssertEqual(resolvedSpec, .fastestSecureCore)
    }

    func testResolverReturnsNormalFastestWhenPrefenceIsFastestAndSecureCoreIsOff() {
        let resolvedSpec = Sut.connectionSpec(for: .fastest, recents: [], secureCore: false)
        XCTAssertEqual(resolvedSpec, .fastest)
    }

    // MARK: Preference Options

    func testResolverReturnsPreferencesWithoutFastestConnection() {
        let connectionSpecs: [ConnectionSpec] = [.fastestSecureCore, .fastest, .poland]
        let recents = OrderedSet<RecentConnection>(connectionSpecs.map { $0.recent(with: .referenceDate) })

        let preferenceModels = withDependencies {
            $0.locale = Locale(identifier: "en")
        } operation: {
            Sut.preferenceModels(for: recents)
        }

        let preferenceModelSpecs = preferenceModels.map(\.preference)
        XCTAssertEqual(preferenceModelSpecs, [.recent(.fastestSecureCore), .recent(.poland)])
    }
}

extension Date {
    static let referenceDate = Date(timeIntervalSince1970: 591_742_800)
    static var earlier: Date { referenceDate.addingTimeInterval(-2_443_332) }
    static var later: Date { referenceDate.addingTimeInterval(2_443_332) }
}

extension ConnectionSpec {
    static let fastest = ConnectionSpec(location: .any(.fastest), features: [])
    static let fastestSecureCore = ConnectionSpec(location: .secureCore(.any(.fastest)), features: [])
    static let franceWithP2P = ConnectionSpec(location: .country(code: "FR", order: .fastest), features: [.p2p])
    static let poland = ConnectionSpec(location: .country(code: "PL", order: .fastest), features: [])

    func recent(with date: Date, pinnedDate: Date? = nil) -> RecentConnection {
        RecentConnection(
            pinnedDate: pinnedDate,
            underMaintenance: false,
            connectionDate: date,
            connection: self
        )
    }
}
