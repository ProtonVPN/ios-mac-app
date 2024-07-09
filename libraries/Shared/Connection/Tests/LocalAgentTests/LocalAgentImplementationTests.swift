//
//  Created on 08/07/2024.
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
import Dependencies

@testable import LocalAgent

final class LocalAgentImplementationTests: XCTestCase {

    func testEventsAreEmittedOnSubsequentSubscriptions() async throws {
        let agent: LocalAgentImplementation = withDependencies {
            $0.date = .constant(.now)
            $0.localAgentClientFactory = .init(createLocalAgentClient: { MockLocalAgentClient() })
        } operation: { LocalAgentImplementation() }

        let firstSubscriptionEventReceived = XCTestExpectation()

        let firstEventStream = agent.createEventStream()
        agent.didReceive(event: .state(.connecting))

        for await _ in firstEventStream {
            firstSubscriptionEventReceived.fulfill()
            break
        }

        await fulfillment(of: [firstSubscriptionEventReceived], timeout: 1.0)

        let secondSubscriptionEventReceived = XCTestExpectation()

        let secondEventStream = agent.createEventStream()
        agent.didReceive(event: .state(.connecting))

        for await _ in secondEventStream {
            secondSubscriptionEventReceived.fulfill()
            break
        }

        await fulfillment(of: [secondSubscriptionEventReceived], timeout: 1.0)
    }
}
