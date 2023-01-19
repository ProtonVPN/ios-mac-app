//
//  Created on 2022-10-18.
//
//  Copyright (c) 2022 Proton AG
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
import VPNShared
@testable import NEHelper

class ServerStatusRefreshTests: ExtensionAPIServiceTestCase {
    var manager: ServerStatusRefreshManager!

    var serverDidChange: (([ServerStatusRequest.Logical]) -> ())?

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.manager = ServerStatusRefreshManager(apiService: apiService,
                                                  timerFactory: timerFactory)
        self.manager.delegate = self
    }

    func testServerStatusNotUnderMaintenance() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server")
        )

        let originalServer = ServerStatusRequest.Logical(id: "logical-original-id",
                                                         status: 1,
                                                         servers: [.mock(id: "original-serverip-id", status: 1)])
        Self.currentLogicalId = originalServer.id
        Self.currentServerIpId = originalServer.servers.first!.id

        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([\.original: originalServer]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServer in
            fatalError("Server did not change, so nothing should have happened")
        }

        manager.updateConnectedIds(logicalId: Self.currentLogicalId, serverId: Self.currentServerIpId)

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {}
        }

        wait(for: [expectations.managerStarted, expectations.endpointHit], timeout: expectationTimeout)
    }

    func testLogicalStatusUnderMaintenanceGetsCallback() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server"),
            callbackInvoked: XCTestExpectation(description: "ServerStatusRefreshManager invoked callback")
        )
        
        let originalServer = ServerStatusRequest.Logical(id: "logical-original-id",
                                                         status: 0,
                                                         servers: [.mock(id: "original-serverip-id", status: 1)])
        Self.currentLogicalId = originalServer.id
        Self.currentServerIpId = originalServer.servers.first!.id
        manager.updateConnectedIds(logicalId: Self.currentLogicalId, serverId: Self.currentServerIpId)
        
        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([\.original: originalServer]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServers in
            XCTAssertEqual(newServers.count, 1)
            XCTAssertEqual(newServers.first?.id, "other-logical-id")
            expectations.callbackInvoked.fulfill()
        }

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {}
        }

        wait(for: [expectations.managerStarted,
                   expectations.endpointHit,
                   expectations.callbackInvoked], timeout: expectationTimeout)
    }

    func testServerIpStatusUnderMaintenanceGetsCallback() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server"),
            callbackInvoked: XCTestExpectation(description: "ServerStatusRefreshManager invoked callback")
        )

        let originalServer = ServerStatusRequest.Logical(id: "logical-original-id",
                                                         status: 1,
                                                         servers: [.mock(id: "original-serverip-id", status: 0),
                                                                   .mock(id: "new-serverip-id", status: 1)])
        Self.currentLogicalId = originalServer.id
        Self.currentServerIpId = originalServer.servers.first!.id
        manager.updateConnectedIds(logicalId: Self.currentLogicalId, serverId: Self.currentServerIpId)

        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([\.original: originalServer]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServers in
            XCTAssertEqual(newServers.count, 1)
            XCTAssertEqual(newServers.first?.id, Self.currentLogicalId)
            XCTAssertEqual(newServers.first?.servers.count, 2)
            expectations.callbackInvoked.fulfill()
        }

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {}
        }

        wait(for: [expectations.managerStarted,
                   expectations.endpointHit,
                   expectations.callbackInvoked], timeout: expectationTimeout)
    }

    func testServerIpGoingAwayGetsCallback() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server"),
            callbackInvoked: XCTestExpectation(description: "ServerStatusRefreshManager invoked callback")
        )

        let newIp = "123.123.123.0"

        Self.currentServerIpId = "original-serverip-id"
        let originalServer = ServerStatusRequest.Logical(id: "logical-original-id",
                                                         status: 1,
                                                         servers: [.mock(entryIp: newIp,
                                                                         id: "different-serverip-id",
                                                                         status: 1)])
        Self.currentLogicalId = originalServer.id
        manager.updateConnectedIds(logicalId: Self.currentLogicalId, serverId: Self.currentServerIpId)

        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([\.original: originalServer]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServers in
            XCTAssertEqual(newServers.count, 1)
            XCTAssertEqual(newServers.first?.id, Self.currentLogicalId)
            XCTAssertEqual(newServers.first?.servers.first?.entryIp, newIp)
            expectations.callbackInvoked.fulfill()
        }

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {}
        }

        wait(for: [expectations.managerStarted,
                   expectations.endpointHit,
                   expectations.callbackInvoked], timeout: expectationTimeout)
    }

    func testResponseParseError() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            firstError: XCTestExpectation(description: "API returned wrong json"),
            secondRequestSucceed: XCTestExpectation(description: "API returned proper response on the second try")
        )
        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .failure(ExtensionAPIServiceError.parseError(nil)),
                                            expectationToFulfill: expectations.firstError)

        serverDidChange = { newServer in
            fatalError("Server did not change, so nothing should have happened")
        }

        manager.updateConnectedIds(logicalId: Self.currentLogicalId, serverId: Self.currentServerIpId)

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {
                let originalServer = ServerStatusRequest.Logical(id: "logical-original-id",
                                                                 status: 1,
                                                                 servers: [.mock(id: "original-serverip-id", status: 1)])
                Self.currentLogicalId = originalServer.id
                Self.currentServerIpId = originalServer.servers.first!.id
                self.serverStatusCallback = self.mockEndpoint(ServerStatusRequest.self,
                                                              result: .success([\.original: originalServer]),
                                                              expectationToFulfill: expectations.secondRequestSucceed)
                self.timerFactory.runRepeatingTimers {}
            }
        }

        wait(for: [expectations.managerStarted, expectations.firstError, expectations.secondRequestSucceed], timeout: expectationTimeout)
    }

    func testServerMaintenanceFlag() {
        let serverInMaintenance = ServerStatusRequest.Server.mock(status: 0)
        let serverNotInMaintenance = ServerStatusRequest.Server.mock(status: 1)
        XCTAssertTrue(serverInMaintenance.underMaintenance)
        XCTAssertFalse(serverNotInMaintenance.underMaintenance)
    }
}

extension ServerStatusRequest.Server {
    static func mock(entryIp: String = "1.2.3.4",
                     exitIp: String = "5.6.7.8",
                     domain: String = "vpn.domain",
                     id: String = "server-id-123",
                     status: Int = 0,
                     label: String = "label",
                     x25519PublicKey: String? = nil,
                     protocolEntries: PerProtocolEntries? = nil
    ) -> ServerStatusRequest.Server {
        ServerStatusRequest.Server(entryIp: entryIp,
                                   exitIp: exitIp,
                                   domain: domain,
                                   id: id,
                                   status: status,
                                   label: label,
                                   x25519PublicKey: x25519PublicKey,
                                   protocolEntries: protocolEntries
        )
    }
}

extension ServerStatusRefreshTests: ServerStatusRefreshDelegate {
    func reconnect(toAnyOf alternatives: [ServerStatusRequest.Logical]) {
        serverDidChange?(alternatives)
    }
}
