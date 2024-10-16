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

    func testPin() {
        let connection = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        var recents = RecentsStorage(array: [connection])
        recents.pin(spec: .defaultFastest)
        XCTAssertTrue(recents.array.first!.pinned)
    }

    func testUnpin() {
        let connection = RecentConnection(pinned: true, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        var recents = RecentsStorage(array: [connection])
        recents.unpin(spec: .defaultFastest)
        XCTAssertFalse(recents.array.first!.pinned)
    }

    func testRemove() {
        let connection = RecentConnection(pinned: false, underMaintenance: false, connectionDate: Date(), connection: .defaultFastest)
        var recents = RecentsStorage(array: [connection])
        recents.remove(spec: .defaultFastest)
        XCTAssertTrue(recents.array.isEmpty)
    }

    func testUpdate() {
        withDependencies {
            $0.date = .constant(.now)
        } operation: {
            var recents = RecentsStorage(array: [])
            recents.updateList(with: .defaultFastest)
            XCTAssertFalse(recents.array.first!.pinned)
        }
    }

    func testSortingPinned() {
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
            var recents = RecentsStorage(array: [one, two])

            XCTAssertEqual(recents.array, [two, one])

            let threeSpec = ConnectionSpec(location: .region(code: "3"), features: [])
            let three = RecentConnection(pinned: true,
                                         underMaintenance: false,
                                         connectionDate: now,
                                         connection: threeSpec)
            recents.updateList(with: threeSpec)
            recents.pin(spec: threeSpec)

            XCTAssertEqual(recents.array, [three, two, one])
        }

    }

    func testTrimming() {
        let now = Date()
        let array = (0...9).map { element in
            RecentConnection(pinned: false,
                             underMaintenance: false,
                             connectionDate: now,
                             connection: .init(location: .region(code: "\(element)"), features: []))
        }
        XCTAssertEqual(array.count, 10)
        let recents = RecentsStorage(array: array)
        XCTAssertEqual(recents.array.count, 8)
    }
}
