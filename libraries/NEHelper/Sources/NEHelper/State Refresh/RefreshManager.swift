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

public class RefreshManager {
    internal let workQueue: DispatchQueue
    internal let timerFactory: TimerFactory

    public enum State {
        case running
        case stopped
    }

    public private(set) var state: State = .stopped
    private var timer: BackgroundTimer?

    public var timerRefreshInterval: TimeInterval {
        fatalError("\(#function) should be overridden by child class")
    }

    init(timerFactory: TimerFactory, workQueue: DispatchQueue) {
        self.timerFactory = timerFactory
        self.workQueue = workQueue
    }

    public func start(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            self?.state = .running
            self?.startTimer()
            completion()
        }
    }

    public func stop(completion: @escaping (() -> Void)) {
        workQueue.async { [weak self] in
            self?.stopTimer()
            self?.state = .stopped
            completion()
        }
    }

    /// - Invariant: Will be called on `workQueue`.
    internal func work() {
        fatalError("\(#function) should be overridden by child class")
    }

    // MARK: - Timer
    /// - Note: Call this function on `workQueue`.
    internal func startTimer() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(workQueue))
        #endif

        timer = timerFactory.scheduledTimer(runAt: Date(),
                                            repeating: timerRefreshInterval,
                                            queue: workQueue) { [weak self] in
            self?.work()
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
