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

import Dependencies
import Domain
import Foundation
import Sharing
import Testing
@testable import VPNAppCore
import VPNShared

@Suite(.serialized)
struct ServerChangeAuthorizerTests {
    private static let username = "test-user"

    private static let config = ServerChangeConfig(
        changeServerAttemptLimit: 3,
        changeServerShortDelayInSeconds: 5,
        changeServerLongDelayInSeconds: 10
    )

    private static let start = Date(timeIntervalSince1970: 1_234_567_890)

    /// Runs `body` with an isolated `defaultAppStorage` + mock keychain (so the per-user
    /// `.serverChangeConnectionStack` resolves), seeding the given `config` and `connectionStack`.
    ///
    /// The authorizer under test is resolved from `\.serverChangeAuthorizer` rather than built
    /// directly, so the tests exercise the same composition the app gets. Each scope is given a
    /// freshly composed instance, because `liveValue` keeps one process-wide availability cache
    /// whose entries would otherwise be served to later cases.
    private func withServerChange<T>(
        date: Date,
        freeTier: Bool = true,
        config: ServerChangeConfig = Self.config,
        connectionStack: [ConnectionStackItem] = [],
        _ body: (ServerChangeAuthorizer) throws -> T
    ) throws -> T {
        let suiteName = "ServerChangeAuthorizerTests-\(Self.username)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername(Self.username)

        return try withDependencies {
            $0.date = .constant(date)
            $0.credentialsProvider = .constant(credentials: .tier(freeTier ? .free : .paid))
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
            $0.serverChangeAuthorizer = .makeLive()
        } operation: {
            @Shared(.serverChangeConfig) var sharedConfig
            $sharedConfig.withLock { $0 = config }
            @Shared(.serverChangeConnectionStack) var sharedStack
            $sharedStack.withLock { $0 = connectionStack }

            @Dependency(\.serverChangeAuthorizer) var authorizer
            return try body(authorizer)
        }
    }

    @Test
    func authorizesServerChangeWhenStackIsEmpty() throws {
        try withServerChange(date: Self.start, connectionStack: []) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .available)
        }
    }

    @Test
    func returnsShortDelayWhenStackContainsRecentServerChange() throws {
        let delayExpiryDate = Self.start.addingTimeInterval(5)
        let connectionStack = [ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false)]

        try withServerChange(date: Self.start, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }

        try withServerChange(date: delayExpiryDate, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .available)
        }
    }

    @Test
    func ignoresNonRandomServerConnectionItems() throws {
        let later = Self.start.addingTimeInterval(1)
        let delayExpiryDate = Self.start.addingTimeInterval(5)
        let nonRandomItem = ConnectionStackItem(intent: .fastest, date: later, upsellNext: false)

        try withServerChange(
            date: Self.start,
            connectionStack: [ConnectionStackItem(intent: .fastest, date: Self.start, upsellNext: false)]
        ) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .available)

            @Shared(.serverChangeConnectionStack) var sharedStack
            $sharedStack.withLock {
                $0 = Array(repeating: nonRandomItem, count: 5)
                    + [ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false)]
            }

            #expect(authorizer.serverChangeAvailability() == .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }
    }

    @Test
    func alwaysReturnsAvailableForPaidUsers() throws {
        let delayExpiryDate = Self.start.addingTimeInterval(5)
        let connectionStack = [ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false)]

        try withServerChange(date: Self.start, freeTier: true, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .unavailable(until: delayExpiryDate, duration: 5, exhaustedSkips: false))
        }

        try withServerChange(date: Self.start, freeTier: false, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .available)
        }
    }

    @Test
    func returnsLongDelayWhenStackContainsRecentServerChangeWithFlagTrue() throws {
        let midDelay = Self.start.addingTimeInterval(5)
        let delayExpiryDate = Self.start.addingTimeInterval(10)
        let connectionStack = [ConnectionStackItem(intent: .random, date: Self.start, upsellNext: true)]

        try withServerChange(date: Self.start, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        try withServerChange(date: midDelay, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .unavailable(until: delayExpiryDate, duration: 10, exhaustedSkips: true))
        }

        try withServerChange(date: delayExpiryDate, connectionStack: connectionStack) { authorizer in
            #expect(authorizer.serverChangeAvailability() == .available)
        }
    }

    @Test
    func registeringAttemptPushesItemWithCorrectFlagValue() throws {
        let second = Self.start.addingTimeInterval(5)
        let third = Self.start.addingTimeInterval(10)
        let config = ServerChangeConfig(
            changeServerAttemptLimit: 2,
            changeServerShortDelayInSeconds: 5,
            changeServerLongDelayInSeconds: 10
        )

        try withServerChange(date: Self.start, config: config, connectionStack: []) { authorizer in
            @SharedReader(.serverChangeConnectionStack) var sharedStack

            authorizer.registerServerChange(connectedAt: Self.start)
            #expect((sharedStack ?? []) == [
                ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false),
            ])

            authorizer.registerServerChange(connectedAt: second)
            #expect((sharedStack ?? []) == [
                ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false),
            ])

            authorizer.registerServerChange(connectedAt: third)
            #expect((sharedStack ?? []) == [
                ConnectionStackItem(intent: .random, date: third, upsellNext: false),
                ConnectionStackItem(intent: .random, date: second, upsellNext: true),
                ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false),
            ])
        }
    }

    @Test
    func servesActiveCooldownFromCacheInsteadOfRereadingStorage() throws {
        let cooldown = ServerChangeAuthorizer.ServerChangeAvailability.unavailable(
            until: Self.start.addingTimeInterval(5),
            duration: 5,
            exhaustedSkips: false
        )

        try withServerChange(
            date: Self.start,
            connectionStack: [ConnectionStackItem(intent: .random, date: Self.start, upsellNext: false)]
        ) { authorizer in
            #expect(authorizer.serverChangeAvailability() == cooldown)

            @Shared(.serverChangeConnectionStack) var sharedStack
            $sharedStack.withLock { $0 = [] }

            // The cooldown hasn't expired yet, so it is answered from the cache — an emptied
            // stack only takes effect once the cached window lapses.
            #expect(authorizer.serverChangeAvailability() == cooldown)
        }
    }
}
