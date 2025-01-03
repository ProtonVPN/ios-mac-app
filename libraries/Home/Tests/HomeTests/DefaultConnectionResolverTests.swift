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

import Foundation
import XCTest
import Collections
import Dependencies
import Domain
@testable import Home

final class DefaultConnectionResolverTests: XCTestCase {
    typealias Sut = DefaultConnectionResolverImplementation

    // MARK: ConnectionSpec Resolving

    func testResolverReturnsNormalFastestRegardlessWhetherSecureCoreIsEnabled() {
        let fastestNonSCSpec = ConnectionSpec(location: .fastest, features: [])

        let resolvedSpecWithSCEnabled = Sut.connectionSpec(for: .fastest, recents: [], isSecureCoreEnabled: true)
        let resolvedSpecWithSCDisabled = Sut.connectionSpec(for: .fastest, recents: [], isSecureCoreEnabled: false)

        XCTAssertEqual(resolvedSpecWithSCEnabled, fastestNonSCSpec)
        XCTAssertEqual(resolvedSpecWithSCDisabled, fastestNonSCSpec)
    }

    func testResolverReturnsMostRecentConnectionWhenPreferenceIsMostRecent() {
        let mostRecentConnection = ConnectionSpec.franceWithP2P.recent(with: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)

        let recents: OrderedSet<RecentConnection> = [mostRecentConnection, olderRecentConnection]
        XCTAssertEqual(recents.mostRecent, mostRecentConnection) // sanity check

        let resolvedSpec = Sut.connectionSpec(for: .mostRecent, recents: recents, isSecureCoreEnabled: false)
        XCTAssertEqual(resolvedSpec, mostRecentConnection.connection)
    }

    func testResolverReturnsSpecificRecentConnectionWhenPrefenceIsSpecific() {
        let resolvedSpec = Sut.connectionSpec(for: .recent(.poland), recents: [], isSecureCoreEnabled: false)
        XCTAssertEqual(resolvedSpec, .poland)
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

        let preferenceModelSpecs = preferenceModels.map { $0.preference }
        XCTAssertEqual(preferenceModelSpecs, [.recent(.fastestSecureCore), .recent(.poland)])
    }
}

extension Date {
    static let referenceDate = Date(timeIntervalSince1970: 591742800)
    static var earlier: Date { referenceDate.addingTimeInterval(-2443332) }
    static var later: Date { referenceDate.addingTimeInterval(2443332) }
}

extension ConnectionSpec {
    static let fastest = ConnectionSpec(location: .fastest, features: [])
    static let fastestSecureCore = ConnectionSpec(location: .secureCore(.fastest), features: [])
    static let franceWithP2P = ConnectionSpec(location: .region(code: "FR"), features: [.p2p])
    static let poland = ConnectionSpec(location: .region(code: "PL"), features: [])

    func recent(with date: Date, pinnedDate: Date? = nil) -> RecentConnection {
        return RecentConnection(
            pinnedDate: pinnedDate,
            underMaintenance: false,
            connectionDate: date,
            connection: self
        )
    }
}
