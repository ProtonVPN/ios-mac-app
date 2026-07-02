//
//  Created on 07/09/2023.
//
//  Copyright (c) 2023 Proton AG
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

import CommonNetworking
import Dependencies
import Foundation
@testable import LegacyCommon
import Sharing
@testable import VPNAppCore
import VPNShared
import XCTest

public class ServerChangeAuthorizerTests: XCTestCase {
    private static let username = "test-user"

    /// Runs `body` with an isolated `defaultAppStorage` + mock keychain (so the per-user
    /// `.serverChangeConnectionStack` resolves), seeding the given `config` and `connectionStack`.
    private func withServerChange(
        date: Date,
        freeTier: Bool = true,
        config: ServerChangeConfig,
        connectionStack: [ConnectionStackItem] = [],
        _ body: () -> Void
    ) {
        let suiteName = "ServerChangeAuthorizerTests-\(Self.username)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername(Self.username)

        withDependencies {
            $0.date = .constant(date)
            $0.credentialsProvider = .constant(credentials: .tier(freeTier ? .freeTier : .paidTier))
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            @Shared(.serverChangeConfig) var sharedConfig
            $sharedConfig.withLock { $0 = config }
            @Shared(.serverChangeConnectionStack) var sharedStack
            $sharedStack.withLock { $0 = connectionStack }
            body()
        }
    }

    private static let config: ServerChangeConfig = .init(
        changeServerAttemptLimit: 3,
        changeServerShortDelayInSeconds: 5,
        changeServerLongDelayInSeconds: 10
    )

    func testAuthorizesServerChangeWhenStackIsEmpty() {
        let sut = ServerChangeAuthorizerImplementation()
        let now = Date()

        withServerChange(date: now, config: Self.config, connectionStack: []) {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testReturnsShortDelayWhenStackContainsRecentServerChange() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let delayExpiryDate = start.addingTimeInterval(5)
        let connectionStack: [ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: false)]

        withServerChange(date: start, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }

        withServerChange(date: delayExpiryDate, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testIgnoresNonRandomServerConnectionItems() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let later = start.addingTimeInterval(1)
        let delayExpiryDate = start.addingTimeInterval(5)

        withServerChange(date: start, config: Self.config, connectionStack: [.init(intent: .fastest, date: start, upsellNext: false)]) {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)

            @Shared(.serverChangeConnectionStack) var sharedStack
            $sharedStack.withLock {
                $0 = [
                    .init(intent: .fastest, date: later, upsellNext: false),
                    .init(intent: .fastest, date: later, upsellNext: false),
                    .init(intent: .fastest, date: later, upsellNext: false),
                    .init(intent: .fastest, date: later, upsellNext: false),
                    .init(intent: .fastest, date: later, upsellNext: false),
                    .init(intent: .random, date: start, upsellNext: false),
                ]
            }
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }
    }

    func testAlwaysReturnsAvailableForPaidUsers() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let delayExpiryDate = start.addingTimeInterval(5)
        let connectionStack: [ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: false)]

        withServerChange(date: start, freeTier: true, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }

        withServerChange(date: start, freeTier: false, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testReturnsLongDelayWhenStackContainsRecentServerChangeWithFlagTrue() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let midDelay = start.addingTimeInterval(5)
        let delayExpiryDate = start.addingTimeInterval(10)
        let connectionStack: [ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: true)]

        withServerChange(date: start, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        withServerChange(date: midDelay, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        withServerChange(date: delayExpiryDate, config: Self.config, connectionStack: connectionStack) {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testRegisteringAttemptPushesItemWithCorrectFlagValue() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let second = start.addingTimeInterval(5)
        let third = start.addingTimeInterval(10)
        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 2,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withServerChange(date: start, config: config, connectionStack: []) {
            @Shared(.serverChangeConnectionStack) var sharedStack

            sut.registerServerChange(connectedAt: start)
            XCTAssertEqual(sharedStack ?? [], [
                ConnectionStackItem(intent: .random, date: start, upsellNext: false),
            ])

            sut.registerServerChange(connectedAt: second)
            XCTAssertEqual(sharedStack ?? [], [
                ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ConnectionStackItem(intent: .random, date: start, upsellNext: false),
            ])

            sut.registerServerChange(connectedAt: third)
            XCTAssertEqual(sharedStack ?? [], [
                ConnectionStackItem(intent: .random, date: third, upsellNext: false),
                ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ConnectionStackItem(intent: .random, date: start, upsellNext: false),
            ])
        }
    }
}
