//
//  Created on 29/01/2024.
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

/// These tests verify that no information is lost in translation from model, to internal database record, back to model
final class ModelToRecordRoundTripTests: TestIsolatedDatabaseTestCase {

    func testVPNServerWithMultipleOverrides() throws {
        let serverToInsert = serverWithMultipleEndpointsAndOverrides
        try sut.upsert(servers: [serverToInsert])

        let result = try sut.getFirstServer(filteredBy: [], orderedBy: .none)
        let server = try XCTUnwrap(result)

        XCTAssertEqual(server, serverToInsert)
        XCTAssertEqual(server.supportedProtocols, .all)
    }

    func testVPNServerWithLimitedProtocolSupport() throws {
        let serverToInsert = serverWithLimitedProtocolSupport
        try sut.upsert(servers: [serverToInsert])

        let result = try sut.getFirstServer(filteredBy: [], orderedBy: .none)
        let server = try XCTUnwrap(result)

        XCTAssertEqual(server, serverToInsert)
        XCTAssertEqual(server.supportedProtocols, [.ikev2, .wireGuardTLS])
    }

    func testVPNServerWithNoOverrides() throws {
        let serverToInsert = serverWithNoOverrides
        try sut.upsert(servers: [serverToInsert])

        let result = try sut.getFirstServer(filteredBy: [], orderedBy: .none)
        let server = try XCTUnwrap(result)

        XCTAssertEqual(server, serverToInsert)
        XCTAssertEqual(server.supportedProtocols, [.all])
    }
}
