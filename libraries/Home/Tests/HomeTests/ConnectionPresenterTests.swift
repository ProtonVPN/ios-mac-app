//
//  Created on 02/01/2025.
//
//  Copyright (c) 2025 Proton AG
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
import OrderedCollections
import XCTest
import Domain
import ConnectionInventory

@testable import HomeShared

class ConnectionInventoryTests: XCTestCase {

    func testMostRecentConnectionFilteredOutWhenNotPinnedAndPreferenceIsMostRecent() {
        let mostRecentConnection = ConnectionSpec.franceWithP2P.recent(with: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .mostRecent,
            recents: [mostRecentConnection, olderRecentConnection],
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, [olderRecentConnection])
    }

    func testMostRecentConnectionIncludedWhenPinnedAndPreferenceIsMostRecent() {
        let mostRecentConnection = ConnectionSpec.franceWithP2P.recent(with: .referenceDate, pinnedDate: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)
        let connections: OrderedSet<RecentConnection> = [mostRecentConnection, olderRecentConnection]

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .mostRecent,
            recents: connections,
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, connections)
    }

    func testFastestFilteredOutWhenNotPinnedAndPreferenceIsFastest() {
        let fastestConnection = ConnectionSpec.fastest.recent(with: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .fastest,
            recents: [fastestConnection, olderRecentConnection],
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, [olderRecentConnection])
    }

    func testFastestIncludedWhenPinnedAndPreferenceIsFastest() {
        let fastestConnection = ConnectionSpec.fastest.recent(with: .referenceDate, pinnedDate: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)
        let connections: OrderedSet<RecentConnection> = [fastestConnection, olderRecentConnection]

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .fastest,
            recents: connections,
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, connections)
    }

    func testSpecifiedConnectionFilteredOutWhenNotPinnedAndPreferenceIsSpecifiedConnection() {
        let specifiedConnection = ConnectionSpec.fastest.recent(with: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .recent(specifiedConnection.connection),
            recents: [specifiedConnection, olderRecentConnection],
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, [olderRecentConnection])
    }

    func testSpecifiedConnectionIncludedWhenPinnedAndPreferenceIsSpecifiedConnection() {
        let specifiedConnection = ConnectionSpec.fastest.recent(with: .referenceDate, pinnedDate: .referenceDate)
        let olderRecentConnection = ConnectionSpec.poland.recent(with: .earlier)
        let connections: OrderedSet<RecentConnection> = [specifiedConnection, olderRecentConnection]

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .recent(specifiedConnection.connection),
            recents: connections,
            currentConnection: nil
        )

        XCTAssertEqual(recentConnections, connections)
    }

    func testDefaultConnectionIncludedAndCurrentConnectionFilteredOutWhenConnected() {
        let currentConnection = ConnectionSpec.poland.recent(with: .referenceDate)
        let specifiedConnection = ConnectionSpec.franceWithP2P.recent(with: .earlier)

        let recentConnections = ConnectionInventory.liveValue.recentConnectionList(
            defaultConnectionPreference: .recent(specifiedConnection.connection),
            recents: [currentConnection, specifiedConnection],
            currentConnection: currentConnection.connection
        )

        XCTAssertTrue(recentConnections.contains(specifiedConnection))
        XCTAssertFalse(recentConnections.contains(currentConnection))
    }
}
