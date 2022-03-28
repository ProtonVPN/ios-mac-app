import XCTest
@testable import Review

final class ReviewTests: XCTestCase {
    func testReviewAfter3SuccessfulConnections() {
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { Date() }, reviewPrompt: prompt)

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

    func testReviewAfter3SuccessfulConnectionsWithIneligiblePlan() {
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { Date() }, reviewPrompt: prompt)

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

    func testReviewAfterBeingConnectedFor5Days() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { date }, reviewPrompt: prompt)

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
        let review = Review(configuration: Configuration(eligiblePlans: ["visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { date }, reviewPrompt: prompt)

        review.connected()
        XCTAssertFalse(prompt.shown)

        date = date.addingTimeInterval(5 * 24 * 60 * 60)
        review.activated()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfterBeingConnectedFor5DaysIsNotTriggeredMultipleTimes() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { date }, reviewPrompt: prompt)

        review.connected()
        XCTAssertFalse(prompt.shown)

        // Activate after 5 days
        date = date.addingTimeInterval(5 * 24 * 60 * 60)
        review.activated()
        XCTAssertTrue(prompt.shown)

        review.activated()
        XCTAssertFalse(prompt.shown)
    }

    func testReviewAfterConnectingAfterPlanPurchase() {
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { Date() }, reviewPrompt: prompt)

        review.planPurchased(plan: "visionary")
        XCTAssertFalse(prompt.shown)

        review.connected()
        XCTAssertTrue(prompt.shown)
    }

    func testReviewAfterConnectingAfterPlanPurchaseWithIneligiblePlan() {
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { Date() }, reviewPrompt: prompt)

        review.planPurchased(plan: "visionary")
        XCTAssertFalse(prompt.shown)

        review.connected()
        XCTAssertFalse(prompt.shown)
    }

    func testFailedConenctionsResetsTheSuccessCount() {
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { Date() }, reviewPrompt: prompt)

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

    func testShowingReviewResetsTheSuccessCount() {
        var date = Date()
        let prompt = ReviewPromptMock()
        let review = Review(configuration: Configuration(eligiblePlans: ["plus", "visionary"], successConnections: 3, daysLastReviewPassed: 5, daysConnected: 4), plan: "plus", dateProvider: { date }, reviewPrompt: prompt)

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

        // 3, show, reset count
        review.connected()
        XCTAssertTrue(prompt.shown)

        // add then days to go over the days passed limit
        date = date.addingTimeInterval(10 * 24 * 60 * 60)

        // 1
        review.connected()
        XCTAssertFalse(prompt.shown)
    }
}
