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
import Foundation
import Testing

import ComposableArchitecture
import Dependencies
import Sharing

import Domain
import Ergonomics

@testable import Domain
@testable import HomeShared

@MainActor
@Suite("Review Tests", .serialized)
struct ReviewTests {
    @Shared(.ratingSettings) var ratingSettings
    @Shared(.didPromptReview) var didPrompt
    @Shared(.userPlan) var userPlan

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
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        // 1
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 2
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 3
        #expect(!didPrompt)
        await store.send(.connected)

        #expect(!didPrompt)

        await store.send(.clear)
    }

    @Test("Prompts after 3 successful connections and 15 days")
    func promptsAfter3ConnectionsAnd15Days() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "plus" }

        // 1
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 2
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 3
        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }
        await store.send(.connected)
        #expect(didPrompt)

        await store.send(.clear)
    }

    @Test("Does not prompt after 3 successful connections with ineligible plan")
    func doesNotPromptWithIneligiblePlanAfter3Connections() async {
        let now = LockIsolated(Date.now)

        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "basic" }

        // 1
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 2
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        // 3
        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }
        await store.send(.connected)
        #expect(!didPrompt)

        await store.send(.clear)
    }

    @Test("Does not prompt after being connected for only 5 days")
    func doesNotPromptAfter5DaysConnected() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "plus" }

        await store.send(.connected)

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        #expect(!didPrompt)

        await store.send(.clear)
    }

    @Test("Prompts after being connected for 5 days following a first connection 15 days ago")
    func promptsAfter5DaysConnectedFollowing15DaysAgoFirstConnection() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "plus" }

        await store.send(.connected)

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }

        await store.send(.disconnected)
        await store.send(.connected)

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        #expect(didPrompt)

        await store.send(.clear)
    }

    @Test("Does not prompt after being connected for 5 days with ineligible plan")
    func doesNotPromptAfter5DaysWithIneligiblePlan() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "basic" }

        await store.send(.connected)

        now.withValue { $0 = $0.addingTimeInterval(.days(5)) }

        await store.send(.activate)
        #expect(!didPrompt)

        await store.send(.clear)
    }

    @Test("Does not prompt twice after being connected for 15 days")
    func doesNotPromptTwiceAfter15DaysConnected() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "plus" }

        await store.send(.connected)

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }

        await store.send(.activate)
        #expect(didPrompt)

        $didPrompt.withLock { $0 = false }
        await store.send(.activate)
        #expect(!didPrompt)

        await store.send(.clear)
    }

    @Test("Failed connections reset the success count")
    func failedConnectionsResetTheSuccessCount() async {
        let now = LockIsolated(Date.now)
        let store = TestStore(initialState: .init()) {
            ReviewFeature()
        } withDependencies: {
            $0.date = .init { now.value }
        }
        store.exhaustivity = .off

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = "plus" }

        // 1
        #expect(!didPrompt)
        await store.send(.connected)
        await store.send(.disconnected)

        now.withValue { $0 = $0.addingTimeInterval(.days(15)) }

        // 2
        await store.send(.connected)
        await store.send(.disconnected)

        // Fail, reset to 0
        await store.send(.connectionFailed)
        #expect(!didPrompt)

        // 1
        await store.send(.connected)
        await store.send(.disconnected)

        // 2
        await store.send(.connected)
        await store.send(.disconnected)

        // 3
        await store.send(.connected)
        #expect(didPrompt)

        await store.send(.clear)
    }
}
