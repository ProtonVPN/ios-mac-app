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

import XCTest
@testable import Review

final class ReviewTests: XCTestCase {
    func testReviewAfter3SuccessfulConnectionsButNotYet14Days() {
        let date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        XCTAssertFalse(prompt.shown)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 2
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 3
        review.connected()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfter3SuccessfulConnectionsAnd15Days() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        XCTAssertFalse(prompt.shown)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 2
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // rewind 15 days
        date = date.addingTimeInterval(15 * 24 * 60 * 60)

        // 3
        review.connected()
        XCTAssertTrue(prompt.shown)
    }

    func testReviewAfter3SuccessfulConnectionsWithIneligiblePlan() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        XCTAssertFalse(prompt.shown)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 2
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // rewind 15 days
        date = date.addingTimeInterval(15 * 24 * 60 * 60)

        // 3
        review.connected()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfterBeingConnectedFor5Days() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        review.connected()
        XCTAssertFalse(prompt.shown)

        // Activate after 5 days
        date = date.addingTimeInterval(5 * 24 * 60 * 60)
        review.activated()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfterBeingConnectedFor5DaysAfterFirstConnection15DaysAgo() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        review.connected()
        XCTAssertFalse(prompt.shown)

        // rewind 15 days
        date = date.addingTimeInterval(15 * 24 * 60 * 60)

        review.disconnect()
        XCTAssertFalse(prompt.shown)

        review.connected()
        XCTAssertFalse(prompt.shown)

        // Activate after 5 days
        date = date.addingTimeInterval(5 * 24 * 60 * 60)
        review.activated()
        XCTAssertTrue(prompt.shown)
    }

    func testReviewAfterBeingConnectedFor5DaysWithIneligiblePlan() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        review.connected()
        XCTAssertFalse(prompt.shown)

        date = date.addingTimeInterval(5 * 24 * 60 * 60)
        review.activated()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfterBeingConnectedFor15DaysIsNotTriggeredMultipleTimes() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        review.connected()
        XCTAssertFalse(prompt.shown)

        // Activate after 15 days
        date = date.addingTimeInterval(15 * 24 * 60 * 60)
        review.activated()
        XCTAssertTrue(prompt.shown)

        review.activated()
        XCTAssertFalse(prompt.shown)
    }

    func testFailedConenctionsResetsTheSuccessCount() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let storage = ReviewDataStorageMock()
        let review = Review(configuration: ReviewConfiguration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4, daysFromFirstConnection: 14), plan: "plus", dateProvider: { date }, reviewPrompt: prompt, dataStorage: storage)

        XCTAssertFalse(prompt.shown)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // rewind 15 days
        date = date.addingTimeInterval(15 * 24 * 60 * 60)

        // 2
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // Fail, reset to 0
        review.connectionFailed()
        XCTAssertFalse(prompt.shown)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 2
        review.connected()
        XCTAssertFalse(prompt.shown)
        review.disconnect()
        XCTAssertFalse(prompt.shown)

        // 3
        review.connected()
        XCTAssertTrue(prompt.shown)
    }
}
