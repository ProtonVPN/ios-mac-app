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
import ExtensionManager
import CoreConnection
import LocalAgent
import Ergonomics

final class CoreConnectionStateTests: XCTestCase {
    func testLocalAgentErrorResolvesToError() async {
        let goTLSError: LAConnectionCreationError = .goTLSError(.privateKeyDoesNotMatchPublicKey, underlyingError: "" as GenericError)
        let state = CoreConnectionState(
            tunnelState: .disconnected(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(.failedToEstablishConnection(goTLSError))
        )

        XCTAssertEqual(state, .disconnected(.agent(.failedToEstablishConnection(goTLSError))))
    }

    func testTunnelConnectingResolvesToStarting() async {
        let state = CoreConnectionState(
            tunnelState: .connecting(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .starting)
    }

    func testTunnelConnectedLocalAgentDisconnectedResolvesToConnecting() async {
        let now = Date.now
        let server = LogicalServerInfo(logicalID: "abcd", serverID: "efgh")
        let response = TunnelConnectionResponse(logicalInfo: server, connectionDate: now)

        let state = CoreConnectionState(
            tunnelState: .connected(response),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .connecting(response))
    }

    func testTunnelConnectingLocalAgentDisconnectedResolvesToStarting() async {
        let state = CoreConnectionState(
            tunnelState: .connecting(nil),
            certAuthState: .idle,
            localAgentState: .disconnected(nil)
        )

        XCTAssertEqual(state, .starting)
    }
}
