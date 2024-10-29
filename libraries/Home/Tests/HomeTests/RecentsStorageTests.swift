//
//  Created on 17/10/2024.
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

import XCTest
@testable import Home
import Domain
import Dependencies
import OrderedCollections

final class RecentsStorageTests: XCTestCase {

    func testPiningASpecMovesTheCorrespondingRecentToTheTopOfTheListsAndMarksItAsPinned() {
        var defaultFastest = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        let specificCity = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date() + 1, connection: .specificCity)
        let specificCountry = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date(), connection: .specificCountry)
        let recents = RecentsStorageImplementation(array: [specificCity, defaultFastest, specificCountry])
        recents.pin(recent: defaultFastest)
        defaultFastest.pinned = true
        XCTAssertEqual(recents.collection, [defaultFastest, specificCity, specificCountry])
    }

    func testUnpiningASpecMovesTheCorrespondingRecentBelowThePinnedAndMarksItAsUnpinned() {
        var defaultFastest = RecentConnection(pinned: true, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        let specificCity = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date() + 2, connection: .specificCity)
        let specificCountry = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date() + 1, connection: .specificCountry)
        let recents = RecentsStorageImplementation(array: [defaultFastest, specificCity, specificCountry])
        recents.unpin(recent: defaultFastest)
        defaultFastest.pinned = false
        XCTAssertEqual(recents.collection, [specificCity, specificCountry, defaultFastest])
    }

    func testRemovingASpecRemovesTheCorrespondingRecent() {
        let defaultFastest = RecentConnection(pinned: true, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        let specificCity = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date() + 2, connection: .specificCity)
        let specificCountry = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date() + 1, connection: .specificCountry)
        let recents = RecentsStorageImplementation(array: [defaultFastest, specificCity, specificCountry])
        recents.remove(recent: defaultFastest)
        XCTAssertEqual(recents.collection, [specificCity, specificCountry])
    }

    func testInsertingANewRecentIsReflectedInTheCollectionAndItsNotPinned() {
        withDependencies {
            $0.date = .constant(.now)
        } operation: {
            let recents = RecentsStorageImplementation(array: [])
            recents.updateList(with: .defaultFastest)
            XCTAssertFalse(recents.collection.first!.pinned)
        }
    }

    func testInsertingANewConnectionAndPinningItMovesTheCorrespondingRecentAboveUnpinnedConnections() {
        let now = Date()
        withDependencies {
            $0.date = .constant(now)
        } operation: {
            let one = RecentConnection(pinned: false,
                                       underMaintenance: false,
                                       connectionDate: now,
                                       connection: .init(location: .region(code: "1"), features: []))
            let two = RecentConnection(pinned: true,
                                       underMaintenance: false,
                                       connectionDate: now,
                                       connection: .init(location: .region(code: "2"), features: []))
            let recents = RecentsStorageImplementation(array: [one, two])

            XCTAssertEqual(recents.collection, [two, one])

            let threeSpec = ConnectionSpec(location: .region(code: "3"), features: [])
            var three = RecentConnection(pinned: false,
                                         underMaintenance: false,
                                         connectionDate: now,
                                         connection: threeSpec)
            recents.updateList(with: threeSpec)
            recents.pin(recent: three)
            three.pinned = true

            XCTAssertEqual(recents.collection[0], three)
            XCTAssertEqual(recents.collection[1], two)
            XCTAssertEqual(recents.collection[2], one)
        }
    }

    func testInitializingRecentsListWithMoreThanAllowedNumberOfConnectionsTrimsTheRecentList() {
        let now = Date()
        let array = (0...9).map { element in
            RecentConnection(pinned: false,
                             underMaintenance: false,
                             connectionDate: now,
                             connection: .init(location: .region(code: "\(element)"), features: []))
        }
        XCTAssertEqual(array.count, 10)
        let recents = RecentsStorageImplementation(array: array)
        XCTAssertEqual(recents.collection.count, 8)
    }
}
