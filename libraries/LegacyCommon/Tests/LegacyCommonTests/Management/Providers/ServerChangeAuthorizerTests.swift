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

import Foundation
import XCTest
import Dependencies
@testable import LegacyCommon

public class ServerChangeAuthorizerTests: XCTestCase {

    func testAuthorizesServerChangeWhenStackIsEmpty() {
        let sut = ServerChangeAuthorizerImplementation()
        let now = Date()

        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 3,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withDependencies {
            $0.date = .constant(now)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { [] }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testReturnsShortDelayWhenStackContainsRecentServerChange() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let delayExpiryDate = start.addingTimeInterval(5)

        let connectionStack: [ServerChangeStorage.ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: false)]
        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 3,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withDependencies {
            $0.date = .constant(start)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }

        withDependencies {
            $0.date = .constant(delayExpiryDate)
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testIgnoresNonRandomServerConnectionItems() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let later = start.addingTimeInterval(1)
        let delayExpiryDate = start.addingTimeInterval(5)

        var connectionStack: [ServerChangeStorage.ConnectionStackItem] = []
        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 3,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withDependencies {
            $0.date = .constant(start)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            connectionStack = [.init(intent: .fastest, date: start, upsellNext: false)]
            XCTAssertEqual(sut.serverChangeAvailability(), .available)

            connectionStack = [
                .init(intent: .fastest, date: later, upsellNext: false),
                .init(intent: .fastest, date: later, upsellNext: false),
                .init(intent: .fastest, date: later, upsellNext: false),
                .init(intent: .fastest, date: later, upsellNext: false),
                .init(intent: .fastest, date: later, upsellNext: false),
                .init(intent: .random, date: start, upsellNext: false)
            ]
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }
    }

    func testAlwaysReturnsAvailableForPaidUsers() {
            let sut = ServerChangeAuthorizerImplementation()
            let start = Date()
            let delayExpiryDate = start.addingTimeInterval(5)

            let connectionStack: [ServerChangeStorage.ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: false)]
            let config: ServerChangeConfig = .init(
                changeServerAttemptLimit: 3,
                changeServerShortDelayInSeconds: 5,
                changeServerLongDelayInSeconds: 10
            )

            withDependencies {
                $0.date = .constant(start)
                $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
                $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
                $0.serverChangeStorage = .init(
                    getConfig: { config },
                    getConnectionStack: { connectionStack }
                )
            } operation: {
                XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
            }

        withDependencies {
            $0.date = .constant(start)
            $0.credentialsProvider = .constant(credentials: .tier(.paidTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }

        withDependencies {
            $0.date = .constant(start)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allEnabled.disabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testReturnsLongDelayWhenStackContainsRecentServerChangeWithFlagTrue() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let midDelay = start.addingTimeInterval(5)
        let delayExpiryDate = start.addingTimeInterval(10)

        let connectionStack: [ServerChangeStorage.ConnectionStackItem] = [.init(intent: .random, date: start, upsellNext: true)]
        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 3,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withDependencies {
            $0.date = .constant(start)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        withDependencies {
            $0.date = .constant(midDelay)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        withDependencies {
            $0.date = .constant(delayExpiryDate)
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack }
            )
        } operation: {
            XCTAssertEqual(sut.serverChangeAvailability(), .available)
        }
    }

    func testRegisteringAttemptPushesItemWithCorrectFlagValue() {
        let sut = ServerChangeAuthorizerImplementation()
        let start = Date()
        let second = start.addingTimeInterval(5)
        let third = start.addingTimeInterval(10)

        var connectionStack: [ServerChangeStorage.ConnectionStackItem] = []
        let config: ServerChangeConfig = .init(
            changeServerAttemptLimit: 2,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        withDependencies {
            $0.credentialsProvider = .constant(credentials: .tier(.freeTier))
            $0.featureFlagProvider = .constant(flags: .allDisabled.enabling(\.showNewFreePlan))
            $0.serverChangeStorage = .init(
                getConfig: { config },
                getConnectionStack: { connectionStack },
                setConnectionStack: { connectionStack = $0 }
            )
        } operation: {
            var expectedItems = [
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: start, upsellNext: false)
            ]
            sut.registerServerChange(connectedAt: start)
            XCTAssertEqual(connectionStack, expectedItems)

            expectedItems = [
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: start, upsellNext: false)
            ]
            sut.registerServerChange(connectedAt: second)
            XCTAssertEqual(connectionStack, expectedItems)

            expectedItems = [
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: third, upsellNext: false),
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ServerChangeStorage.ConnectionStackItem(intent: .random, date: start, upsellNext: false)
            ]
            sut.registerServerChange(connectedAt: third)
            XCTAssertEqual(connectionStack, expectedItems)
        }
    }
}
