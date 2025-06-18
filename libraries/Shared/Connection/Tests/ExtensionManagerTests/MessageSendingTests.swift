//
//  Created on 13/06/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Ergonomics
import ExtensionIPC
import NetworkExtension
import Testing
import XCTest

@testable import ExtensionManager

final class MessageSendingTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // We await the result of tasks here.
        // If something goes wrong the test will hang for ages until killed, unless we stop on the first failure
        continueAfterFailure = false
    }

    @MainActor
    func testThrowsSendingErrorWhenSendProviderMessageThrows() async throws {
        let internalSendFailure = NEVPNError(.configurationInvalid)

        let connection = VPNSessionMock(status: .connected, connectedDate: nil, lastDisconnectError: nil)
        connection.messageHandler = MessageHandler.usingInternalSend
        connection.internalMessageSender = { _ in
            // According to Apple documentation, possible errors include:
            // - NEVPNErrorConfigurationInvalid
            // - NEVPNErrorConfigurationDisabled
            throw internalSendFailure
        }

        await #expect(throws: ProviderMessageError.sendingError(.internalSendFailed(internalSendFailure))) {
            try await connection.send(.refreshCertificate(features: nil))
        }
    }

    @MainActor
    func testThrowsRetriesExhaustedAfterRetryLimitReached() async throws {
        let clock = TestClock()

        let connection = VPNSessionMock(status: .connected, connectedDate: nil, lastDisconnectError: nil)
        connection.messageHandler = MessageHandler.usingInternalSend

        let messageSent = XCTestExpectation(description: "Message should have been sent 5 times")
        // Based on the static value, defined in `extension NETunnelProviderSession: VPNSession`
        messageSent.expectedFulfillmentCount = 5

        connection.internalMessageSender = { _ in
            messageSent.fulfill()
            return nil
        }

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            let task = Task { try await connection.send(.refreshCertificate(features: nil)) }

            var delays = 0
            for _ in 1 ... 4 {
                // We've made our send instant, and the delay is 1 second between retries
                await clock.advance(by: .seconds(1))
                delays += 1
            }
            XCTAssertEqual(delays, 4, "Sanity check - off by one errors are the worst")

            await fulfillment(of: [messageSent], timeout: 0)

            let result = await task.result
            let providerMessageError = try XCTUnwrap(result.error as? ProviderMessageError)
            XCTAssertEqual(providerMessageError, .noDataReceived)
        }
    }

    /// Verifies the implementation of `send(WireguardProviderMessage:)` is cancelled properly
    @MainActor
    func testCancellingTaskPreventsRetries() async throws {
        let clock = TestClock()

        let connection = VPNSessionMock(status: .connected, connectedDate: nil, lastDisconnectError: nil)
        connection.messageHandler = MessageHandler.usingInternalSend

        let messageSent = XCTestExpectation(description: "Original message should have been sent")
        let retrySent = XCTestExpectation(description: "Message should have been retried")

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            connection.internalMessageSender = { _ in
                messageSent.fulfill()
                try? await clock.sleep(for: .seconds(10))
                return nil
            }

            let task = Task {
                // Call the function we are ultimately testing
                try await connection.send(.refreshCertificate(features: nil))
            }

            await fulfillment(of: [messageSent], timeout: 1)
            await clock.advance(by: .seconds(10))

            connection.internalMessageSender = { _ in
                retrySent.fulfill()
                try? await clock.sleep(for: .seconds(10))
                return nil
            }

            await clock.advance(by: .seconds(1))
            await fulfillment(of: [retrySent], timeout: 0)

            connection.internalMessageSender = { _ in
                XCTFail("Task should have been cancelled before second retry was sent")
                return Data()
            }

            task.cancel()
            await clock.advance(by: .seconds(1))

            let result = await task.result
            let providerMessageError = try XCTUnwrap(result.error as? ProviderMessageError)
            XCTAssertEqual(providerMessageError, .cancelled)
        }
    }
}
