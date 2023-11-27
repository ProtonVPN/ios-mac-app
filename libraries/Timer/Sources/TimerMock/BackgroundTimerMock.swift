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
import Timer

public class BackgroundTimerMock: BackgroundTimer {
    let nextRunTime: Date
    let repeating: Double?
    let queue: DispatchQueue
    let closure: (() async -> Void)

    public var isValid: Bool = true

    public var nextTime: Date { nextRunTime }

    public func invalidate() {
        isValid = false
    }

    public init(nextRunTime: Date, repeating: Double?, queue: DispatchQueue, closure: @escaping (() async -> Void)) {
        self.nextRunTime = nextRunTime
        self.repeating = repeating
        self.queue = queue
        self.closure = closure
    }
}

public final class TimerFactoryMock: TimerFactory {
    public var repeatingTimers: [BackgroundTimerMock] = []
    public var scheduledWork: [(interval: DispatchTimeInterval, closure: (() -> Void))] = []

    public var timerWasAdded: (() -> Void)?
    public var workWasScheduled: (() -> Void)?

    public var lastQueueWorkWasScheduledOn: DispatchQueue?

    public func runRepeatingTimers(done: (() -> Void)? = nil) {
        let group = DispatchGroup()

        for timer in repeatingTimers {
            guard timer.isValid else { continue }

            group.enter()
            timer.queue.async {
                Task {
                    await timer.closure()
                    group.leave()
                }
            }
        }

        guard let done = done else { return }

        group.notify(queue: .main, execute: done)
    }

    public func runAllScheduledWork() {
        lastQueueWorkWasScheduledOn!.async {
            while !self.scheduledWork.isEmpty {
                self.scheduledWork.removeFirst().closure()
            }
        }
    }

    public func scheduledTimer(runAt nextRunTime: Date, repeating: Double?, leeway: DispatchTimeInterval?, queue: DispatchQueue, _ closure: @escaping (() async -> Void)) -> BackgroundTimer {
        lastQueueWorkWasScheduledOn = queue

        let timer = BackgroundTimerMock(nextRunTime: nextRunTime, repeating: repeating, queue: queue, closure: closure)
        repeatingTimers.append(timer)
        timerWasAdded?()
        return timer
    }

    public func scheduleAfter(_ interval: DispatchTimeInterval, on queue: DispatchQueue, _ closure: @escaping (() -> Void)) {
        lastQueueWorkWasScheduledOn = queue

        scheduledWork.append((interval, closure))
        workWasScheduled?()
    }

    public init() { /* empty */ }
}
