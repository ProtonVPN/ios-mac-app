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

protocol RepeatingTimerProtocol {
}

protocol TimerFactory {
    func repeatingTimer(runAt nextRunTime: Date,
                        repeating: Double,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> RepeatingTimerProtocol

    func scheduleAfter(seconds: Int,
                       on queue: DispatchQueue,
                       _ closure: @escaping (() -> Void))
}

final class TimerFactoryImplementation: TimerFactory {
    func repeatingTimer(runAt nextRunTime: Date,
                        repeating: Double,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> RepeatingTimerProtocol {
        BackgroundTimer(runAt: nextRunTime, repeating: repeating, queue: queue, closure)
    }

    func scheduleAfter(seconds: Int, on queue: DispatchQueue, _ closure: @escaping (() -> Void)) {
        queue.asyncAfter(deadline: .now() + .seconds(seconds), execute: closure)
    }
}

final class BackgroundTimer: RepeatingTimerProtocol {
    private let timerSource: DispatchSourceTimer
    private let closure: () -> Void

    private enum State {
        case suspended
        case resumed
    }
    private var state: State = .resumed

    init(runAt nextRunTime: Date, repeating: Double, queue: DispatchQueue, _ closure: @escaping () -> Void) {
        self.closure = closure
        timerSource = DispatchSource.makeTimerSource(queue: queue)

        timerSource.schedule(deadline: .now() + .seconds(Int(nextRunTime.timeIntervalSinceNow)), repeating: repeating, leeway: .seconds(10)) // We have at least minute before app (if in foreground) may start refreshing cert. So 10 seconds later is ok.
        timerSource.setEventHandler { [weak self] in
            if repeating <= 0 { // Timer should not repeat, so lets suspend it
                self?.timerSource.suspend()
                self?.state = .suspended
            }
            self?.closure()
        }
        timerSource.resume()
        state = .resumed
    }

    deinit {
        timerSource.setEventHandler {}
        if state == .suspended {
            timerSource.resume()
        }
        timerSource.cancel()
    }
}
