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
import Atomics

final class TimerTests: XCTestCase {
    
    private var factory: TimerFactoryImplementation!
    
    // We have to have a strong reference to timer object because otherwise it will be deallocated and timer will not execute out closure
    var timer: BackgroundTimer?
    
    override func setUp() {
        super.setUp()
        factory = TimerFactoryImplementation()
    }
    
    override func tearDown() {
        super.tearDown()
        factory = nil
    }
    
    func testDateTimer() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        timer = factory.scheduledTimer(runAt: Date(), queue: DispatchQueue.global()) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
        timer = nil
    }
    
    func testDateWithLeewayTimer() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        timer = factory.scheduledTimer(runAt: Date(), leeway: .never, queue: DispatchQueue.global()) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
        timer = nil
    }
    
    func testTimeIntervalTimer() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        timer = factory.scheduledTimer(timeInterval: 0.01, repeats: false, queue: DispatchQueue.global()) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
        timer = nil
    }
    
    func testDispatchTimeIntervalTimer() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        factory.scheduleAfter(.milliseconds(1), on: .global()) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testRepeatingTimer() throws {
        let repeats = 3
        let expectation = XCTestExpectation(description: "Timer closure was called \(repeats) times")
        let counter = ManagedAtomic<Int>(0)

        timer = factory.scheduledTimer(runAt: Date(), repeating: 0.1, queue: DispatchQueue.global()) {
            let value = counter.loadThenWrappingIncrement(ordering: .sequentiallyConsistent)
            guard value < repeats else {
                if value == repeats {
                    expectation.fulfill()
                }
                return
            }
        }
        
        wait(for: [expectation], timeout: 10)
        timer = nil
    }
    
    func testRepeatingTimeIntervalTimer() throws {
        let repeats = 3
        let expectation = XCTestExpectation(description: "Timer closure was called \(repeats) times")
        let counter = ManagedAtomic<Int>(0)

        timer = factory.scheduledTimer(timeInterval: 0.01, repeats: true, queue: .global()) {
            let value = counter.loadThenWrappingIncrement(ordering: .sequentiallyConsistent)
            guard value < repeats else {
                if value == repeats {
                    expectation.fulfill()
                }
                return
            }
        }
        
        wait(for: [expectation], timeout: 1)
        timer = nil
    }

    func testTimerDoesntFireRightAfterCreation() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")
        expectation.isInverted = true

        timer = factory.scheduledTimer(timeInterval: 11, repeats: true, queue: DispatchQueue.global()) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
        timer = nil
    }

    func testNextTimeIsSet() throws {
        let nextRun = Date().addingTimeInterval(100.0)
        timer = factory.scheduledTimer(runAt: nextRun, repeating: 1, queue: DispatchQueue.global()) {
        }
        XCTAssertNotNil(timer?.nextTime, "Next run time should be set")
        XCTAssertEqual(timer?.nextTime, nextRun)
        timer = nil
    }

    func testNextTimeIsUpdatedOnEachRun() throws {
        let expectation = XCTestExpectation(description: "Timer closure was called")

        let interval = 888.888
        let firstRun = Date().addingTimeInterval(0.01)
        let nextRunDate = Date(timeIntervalSinceNow: 11) // Any date object

        timer = factory.scheduledTimer(runAt: firstRun, repeating: interval, queue: DispatchQueue.global()) {
            XCTAssertEqual(self.timer?.nextTime, nextRunDate.addingTimeInterval(interval), "New nextTime has to be updated")
            expectation.fulfill()
        }
        // Inject mocked date
        (timer as! BackgroundTimerImplementation).currentDate = { nextRunDate }

        XCTAssertEqual(timer?.nextTime, firstRun)

        wait(for: [expectation], timeout: 0.1)
        timer = nil
    }
}
