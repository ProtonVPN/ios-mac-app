//
//  Created on 2022-05-24.
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
import XCTest

final class MockTimerFactory: TimerFactory & RepeatingTimerProtocol {
    public var repeatingTimers: [(nextRunTime: Date, repeating: Double, closure: (() -> Void))] = []
    public var scheduledWork: [(seconds: Int, closure: (() -> Void))] = []

    public var timerWasAdded: (() -> Void)?
    public var workWasScheduled: (() -> Void)?

    public var lastQueueWorkWasScheduledOn: DispatchQueue?

    func runRepeatingTimers() {
        for timer in repeatingTimers {
            lastQueueWorkWasScheduledOn!.async {
                timer.closure()
            }
        }
    }

    func runAllScheduledWork() {
        lastQueueWorkWasScheduledOn!.async {
            while !self.scheduledWork.isEmpty {
                self.scheduledWork.removeFirst().closure()
            }
        }
    }

    func repeatingTimer(runAt nextRunTime: Date, repeating: Double, queue: DispatchQueue, _ closure: @escaping (() -> Void)) -> RepeatingTimerProtocol {
        lastQueueWorkWasScheduledOn = queue

        repeatingTimers.append((nextRunTime, repeating, closure))
        timerWasAdded?()
        return self
    }

    func scheduleAfter(seconds: Int, on queue: DispatchQueue, _ closure: @escaping (() -> Void)) {
        lastQueueWorkWasScheduledOn = queue
        
        scheduledWork.append((seconds, closure))
        workWasScheduled?()
    }
}
