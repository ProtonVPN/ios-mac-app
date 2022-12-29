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
@testable import NEHelper

class ServerStatusRefreshTests: ExtensionAPIServiceTestCase {
    var manager: ServerStatusRefreshManager!

    var serverDidChange: (([ServerStatusRequest.Logical]) -> ())?

    override func setUpWithError() throws {
        try super.setUpWithError()

        self.manager = ServerStatusRefreshManager(apiService: apiService,
                                                  timerFactory: timerFactory) { [unowned self] newServer in
            serverDidChange?([])
        }
    }

    func testServerStatusNotUnderMaintenance() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server")
        )
        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([:]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServer in
            fatalError("Server did not change, so nothing should have happened")
        }

        manager.updateConnectedServerId(Self.currentServerId)

        manager.start { [unowned self] in
            expectations.managerStarted.fulfill()
            timerFactory.runRepeatingTimers {}
        }

        wait(for: [expectations.managerStarted, expectations.endpointHit], timeout: expectationTimeout)
    }

    func testServerStatusUnderMaintenanceGetsCallback() {
        let expectations = (
            managerStarted: XCTestExpectation(description: "Manager was started"),
            endpointHit: XCTestExpectation(description: "API returned no change in server"),
            callbackInvoked: XCTestExpectation(description: "ServerStatusRefreshManager invoked callback")
        )
        
        let originalServer = ServerStatusRequest.Logical(id: "logical-original-id", status: 0, servers: [])
        Self.currentServerId = originalServer.id
        manager.updateConnectedServerId(Self.currentServerId)
        
        serverStatusCallback = mockEndpoint(ServerStatusRequest.self,
                                            result: .success([\.original: originalServer]),
                                            expectationToFulfill: expectations.endpointHit)

        serverDidChange = { newServers in
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
}
