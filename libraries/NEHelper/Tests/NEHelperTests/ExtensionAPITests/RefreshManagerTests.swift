//
//  Created on 2023-02-24.
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
import Timer
@testable import NEHelper

final class RefreshManagerTests: XCTestCase {

    /// Make sure `work` is not run right after manager is created.
    func testFirstRunIsAfterRefreshIntervalTimePassed() throws {
        let expectationStart = XCTestExpectation(description: "Timer was started")
        let expectationWork = XCTestExpectation(description: "Timer work closure was called while it shouldn't")
        expectationWork.isInverted = true

        let timerFactory = TimerFactoryImplementation()
        let manager = TestRefreshManager(timerFactory: timerFactory, workQueue: DispatchQueue.main, interval: 888) {
            expectationWork.fulfill()
        }
        manager.start {
            expectationStart.fulfill()
        }

        wait(for: [expectationStart, expectationWork], timeout: 0.1)
    }

}

private class TestRefreshManager: RefreshManager {

    init(timerFactory: TimerFactory, workQueue: DispatchQueue, interval: TimeInterval, workCallback: @escaping (() -> Void)) {
        self.workCallback = workCallback
        self._interval = interval
        super.init(timerFactory: timerFactory, workQueue: workQueue)
    }

    var workCallback: (() -> Void)

    override internal func work() {
        workCallback()
    }

    private let _interval: TimeInterval

    override public var timerRefreshInterval: TimeInterval {
        _interval
    }
}
