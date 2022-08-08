//
//  Created on 2022-08-12.
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
@testable import Timer
@testable import TimerMock

final class BackgroundTimerMockTests: XCTestCase {

    private var factory: TimerFactoryMock!

    // We have to have a strong reference to timer object because otherwise it will be deallocated and timer will not execute out closure
    var timer: BackgroundTimer?

    override func setUp() {
        super.setUp()
        factory = TimerFactoryMock()
    }

    override func tearDown() {
        super.tearDown()
        factory = nil
    }

    func testRepeatingRunner() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        let expectationRepeatingTimersAreDone = XCTestExpectation(description: "Done closure after repeating timers was run")
        expectationRepeatingTimersAreDone.assertForOverFulfill = true
        expectationRepeatingTimersAreDone.expectedFulfillmentCount = expectation.expectedFulfillmentCount - 1

        let expectationInvalidatedTimer = XCTestExpectation(description: "Invalidated timers closure should not be run")
        expectationInvalidatedTimer.isInverted = true

        timer = factory.scheduledTimer(runAt: Date(), repeating: 0.01, queue: DispatchQueue.global()) {
            expectation.fulfill()
        }
        var invalidTimer = factory.scheduledTimer(runAt: Date(), repeating: 0.01, queue: DispatchQueue.global()) {
            expectationInvalidatedTimer.fulfill()
        }
        invalidTimer.invalidate()

        // Run once without done closure
        factory.runRepeatingTimers()

        // Run with done closure and count how many times it was called
        for _ in 1...expectation.expectedFulfillmentCount - 1 {
            factory.runRepeatingTimers {
                expectationRepeatingTimersAreDone.fulfill()
            }
        }

        wait(for: [expectation, expectationInvalidatedTimer, expectationRepeatingTimersAreDone], timeout: 1)
        timer = nil
    }

    func testScheduledRunner() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        for _ in 1...expectation.expectedFulfillmentCount {
            factory.scheduleAfter(.milliseconds(1), on: DispatchQueue.global()) {
                expectation.fulfill()
            }
        }
        factory.runAllScheduledWork()

        wait(for: [expectation], timeout: 1)
        timer = nil
    }

}
