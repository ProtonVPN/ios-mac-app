//
//  Created on 29/03/2023.
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

import XCTest
@testable import Timer
@testable import TimerMock

final class ForegroundTimerTests: XCTestCase {

    func testForegroundTimerFiresNormally() throws {
        let expectation = XCTestExpectation(description: "Foreground timer should fire when scheduled if it has not been suspended")
        expectation.expectedFulfillmentCount = 1

        let timer = ForegroundTimerImplementation(runAt: Date().addingTimeInterval(0.1), repeating: nil, leeway: .none, queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.2)
        XCTAssertTrue(timer.isValid)
    }

    func testForegroundTimerDoesNotFireWhenSuspended() throws {
        let shouldNotFireWhileSuspended = XCTestExpectation(description: "Foreground timer should not fire while suspended")
        let shouldFireAfterResuming = XCTestExpectation(description: "Foreground timer should fire after resuming")
        shouldNotFireWhileSuspended.isInverted = true

        let timer = ForegroundTimerImplementation(runAt: Date().addingTimeInterval(0.1), repeating: nil, leeway: .none, queue: .main) {
            shouldNotFireWhileSuspended.fulfill()
            shouldFireAfterResuming.fulfill()
        }
        timer.suspend()
        wait(for: [shouldNotFireWhileSuspended], timeout: 0.2)

        timer.resume()
        wait(for: [shouldFireAfterResuming], timeout: 0.2)
    }

    func testConsecutiveResumeOrSuspendDoesNotCauseException() throws {
        let shouldFireAfterResuming = XCTestExpectation(description: "Foreground timer should fire after resuming")
        let timer = ForegroundTimerImplementation(runAt: Date().addingTimeInterval(0.1), repeating: nil, leeway: .none, queue: .main) {
            shouldFireAfterResuming.fulfill()
        }

        timer.resume()
        timer.resume()

        timer.suspend()
        timer.suspend()

        timer.resume()
        wait(for: [shouldFireAfterResuming], timeout: 0.2)

        XCTAssert(timer.isValid, "Timer should still be valid after consecutive suspends and resumes.")
    }
}

