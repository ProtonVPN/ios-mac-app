//
//  Created on 20/06/2024.
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
import Connection
import ConnectionFoundations

final class ConnectionStateTests: XCTestCase {

    func testLocalAgentErrorResolvesToError() async {
        let state = ConnectionState(
            tunnelState: .disconnected(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(.failedToEstablishConnection(""))
        )

        XCTAssertEqual(state, .disconnected(.agent(.failedToEstablishConnection(""))))
    }

    func testTunnelConnectingResolvesToConnecting() async {
        let state = ConnectionState(
            tunnelState: .connecting(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .connecting(nil))
    }

    func testTunnelConnectedLocalAgentDisconnectedResolvesToConnecting() async {
        let server = LogicalServerInfo(logicalID: "abcd", serverID: "efgh")

        let state = ConnectionState(
            tunnelState: .connected(server),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .connecting(nil))
    }

    func testTunnelConnectingLocalAgentDisconnectedResolvesToConnecting() async {
        let state = ConnectionState(
            tunnelState: .connecting(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .connecting(nil))
    }
}
