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

struct MockBackgroundTimer: BackgroundTimerProtocol {
    let nextRunTime: Date
    let repeating: Double?
    let queue: DispatchQueue
    let closure: (() -> Void)

    var isValid: Bool = true

    mutating func invalidate() {
        isValid = false
    }
}

final class MockTimerFactory: TimerFactory {
    public var repeatingTimers: [MockBackgroundTimer] = []
    public var scheduledWork: [(interval: DispatchTimeInterval, closure: (() -> Void))] = []

    public var timerWasAdded: (() -> Void)?
    public var workWasScheduled: (() -> Void)?

    public var lastQueueWorkWasScheduledOn: DispatchQueue?

    func runRepeatingTimers() {
        for timer in repeatingTimers {
            guard timer.isValid else { continue }

            timer.queue.async {
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

    func scheduledTimer(runAt nextRunTime: Date, repeating: Double?, queue: DispatchQueue, _ closure: @escaping (() -> Void)) -> BackgroundTimerProtocol {
        lastQueueWorkWasScheduledOn = queue

        let timer = MockBackgroundTimer(nextRunTime: nextRunTime, repeating: repeating, queue: queue, closure: closure)
        repeatingTimers.append(timer)
        timerWasAdded?()
        return timer
    }

    func scheduleAfter(_ interval: DispatchTimeInterval, on queue: DispatchQueue, _ closure: @escaping (() -> Void)) {
        lastQueueWorkWasScheduledOn = queue
        
        scheduledWork.append((interval, closure))
        workWasScheduled?()
    }
}
