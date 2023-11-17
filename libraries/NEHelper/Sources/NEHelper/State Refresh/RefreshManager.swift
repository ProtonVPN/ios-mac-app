//
//  Created on 2022-10-19.
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
import VPNShared
import Timer

/// Parent class for managers that have to perform some tasks periodically.
public class RefreshManager {
    internal let workQueue: DispatchQueue
    internal let timerFactory: TimerFactory

    public enum State {
        case running
        case stopped
    }

    public private(set) var state: State = .stopped
    private var timer: BackgroundTimer?
    private var nextRunTime: Date?

    public var timerRefreshInterval: TimeInterval {
        fatalError("\(#function) should be overridden by child class")
    }

    init(timerFactory: TimerFactory, workQueue: DispatchQueue) {
        self.timerFactory = timerFactory
        self.workQueue = workQueue
    }

    public func start(completion: @escaping (() -> Void)) {
        log.debug("Starting refresh manager...", category: .userCert)
        workQueue.async { [weak self] in
            self?.state = .running
            self?.startTimer()
            log.debug("Refresh manager started!", category: .userCert)
            completion()
        }
    }

    public func stop(completion: @escaping (() -> Void)) {
        log.debug("Stopping refresh manager...", category: .userCert)
        workQueue.async { [weak self] in
            self?.stopTimer()
            self?.state = .stopped
            log.debug("Refresh manager stopped!", category: .userCert)
            completion()
        }
    }

    /// Pause manager in case when phone goes to sleep.
    ///
    /// This saves the time when timer was planned to run so after manager is resumed
    /// it can restart timer to be run at planned time. This way if sleep was longer
    /// than interval, work will be done right after resuming instead of waiting for
    /// one more `timerRefreshInterval`.
    public func suspend(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            self?.nextRunTime = self?.timer?.nextTime
            self?.stopTimer()
            self?.state = .stopped
            completion()
        }
    }

    public func resume(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            log.debug("Timer for \(self) resumed. Next run planned in \(self.nextRunTime?.timeIntervalSinceNow ?? self.timerRefreshInterval) seconds", category: .connection)

            self.state = .running
            self.startTimer(firstRunAfter: self.nextRunTime?.timeIntervalSinceNow)
            completion()
        }
    }

    /// - Invariant: Will be called on `workQueue`.
    internal func work() async {
        fatalError("\(#function) should be overridden by child class")
    }

    // MARK: - Timer

    /// Start a timer that runs with `timerRefreshInterval` interval
    ///
    /// - Parameter firstRunAfter: If nil, first invocation of `work` will be after `timerRefreshInterval`.
    /// Otherwise first run of `work` will be performed after this number of seconds or now if value is negative.
    ///
    /// - Note: Call this function on `workQueue`.
    internal func startTimer(firstRunAfter: TimeInterval? = nil) {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        let firstRunAt = firstRunAfter != nil
            ? Date().addingTimeInterval(min(firstRunAfter!, 0))
            : Date().addingTimeInterval(timerRefreshInterval)

        timer = timerFactory.scheduledTimer(runAt: firstRunAt,
                                            repeating: timerRefreshInterval,
                                            queue: workQueue) { [weak self] in
            Task { [weak self] in
                await self?.work()
            }
        }
    }

    /// Stop the timer by deinit'ing it.
    /// - Note: Call this function on `workQueue`.
    internal func stopTimer() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        self.timer = nil
    }
}
