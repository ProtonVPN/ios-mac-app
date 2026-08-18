//
//  Created on 30.03.2022.
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
import ComposableArchitecture
import Dependencies
@testable import Domain
import Ergonomics
import Foundation
@testable import HomeShared
import Sharing
import Testing

// Serialized to reduce contention on the process-global main-serial-executor
@MainActor
@Suite("Review Tests", .serialized)
struct ReviewTests {
    @Shared(.ratingSettings) var ratingSettings
    @Shared(.didPromptReview) var didPrompt
    @Shared(.userPlan) var userPlan
    @Shared(.connectionState) var connectionState
    @Shared(.successfulConnectionsInARow) var successfulConnectionsInARow
    @Shared(.whenFirstSuccessfulConnectionStarted) var successfulTimestamp
    @Shared(.whenActiveConnectionStarted) var activeConnectionStartTimestamp

    init() {
        $ratingSettings.withLock {
            $0 = .init(
                eligiblePlans: ["plus", "visionary"],
                successConnections: 3,
                daysLastReviewPassed: 5,
                daysConnected: 4,
                daysFromFirstConnection: 14
            )
        }
        $didPrompt.withLock { $0 = false }
        $userPlan.withLock { $0 = nil }
    }

    @Test("Does not prompt if days from first connection not high enough")
    func doesNotPromptIfDaysNotHighEnough() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off

        $successfulConnectionsInARow.withLock { $0 = 3 }
        $userPlan.withLock { $0 = "plus" }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))

        #expect(!didPrompt)
    }

    @Test("Prompts after 3 successful connections and 15 days")
    func promptsAfter3ConnectionsAnd15Days() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off
        $userPlan.withLock { $0 = "plus" }
        $successfulTimestamp.withLock { $0 = now.value }

        #expect(!didPrompt)

        $successfulConnectionsInARow.withLock { $0 = 3 }

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(didPrompt)
    }

    @Test("Does not prompt after 3 successful connections with ineligible plan")
    func doesNotPromptWithIneligiblePlanAfter3Connections() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()

        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off

        $userPlan.withLock { $0 = "basic" }

        // 1
        #expect(!didPrompt)
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))

        // 2
        #expect(!didPrompt)
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))

        // 3
        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(!didPrompt)
    }

    @Test("Does not prompt after being connected for only 5 days")
    func doesNotPromptAfter5DaysConnected() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off

        $userPlan.withLock { $0 = "plus" }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(!didPrompt)
    }

    @Test("Prompts after being connected for 5 days following a first connection 15 days ago")
    func promptsAfter5DaysConnectedFollowing15DaysAgoFirstConnection() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off

        $userPlan.withLock { $0 = "plus" }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        $successfulTimestamp.withLock { $0 = now.value }

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        $activeConnectionStartTimestamp.withLock { $0 = now.value }

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(didPrompt)
    }

    @Test("Does not prompt after being connected for 5 days with ineligible plan")
    func doesNotPromptAfter5DaysWithIneligiblePlan() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off

        $userPlan.withLock { $0 = "basic" }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(!didPrompt)
    }

    @Test("Does not prompt twice after being connected for 15 days")
    func doesNotPromptTwiceAfter15DaysConnected() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
        }
        store.exhaustivity = .off
        $userPlan.withLock { $0 = "plus" }
        $successfulTimestamp.withLock { $0 = now.value }
        $successfulConnectionsInARow.withLock { $0 = 3 }

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(didPrompt)

        $didPrompt.withLock { $0 = false }
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(!didPrompt)
    }

    @Test("Failed connections reset the success count")
    func failedConnectionsResetTheSuccessCount() async {
        let now = LockIsolated(Date.now)
        let testClock = TestClock()
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
            $0.continuousClock = testClock
            let implementation = RatingBoosterImplementation()
            $0.ratingBooster = RatingBooster(
                connectionFailed: implementation.connectionFailed,
                didConnect: implementation.didConnect,
                didDisconnect: implementation.didDisconnect
            )
        }
        store.exhaustivity = .off

        $userPlan.withLock { $0 = "plus" }

        #expect(!didPrompt)
        $successfulConnectionsInARow.withLock { $0 = 1 }
        $activeConnectionStartTimestamp.withLock { $0 = now.value }
        $successfulTimestamp.withLock { $0 = now.value }

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }

        $successfulConnectionsInARow.withLock { $0 = 2 }

        // Fail: the count and the active-connection timestamp are reset.
        await store.send(.connectionFailed)
        #expect(successfulConnectionsInARow == 0)
        #expect(activeConnectionStartTimestamp == nil)
        #expect(!didPrompt)

        $successfulConnectionsInARow.withLock { $0 = 3 }
        $activeConnectionStartTimestamp.withLock { $0 = now.value }

        await store.send(.activate)
        await testClock.advance(by: .seconds(1))
        #expect(!didPrompt)
        await store.send(.activate)
        await testClock.advance(by: .seconds(2))
        #expect(didPrompt)
    }
}
