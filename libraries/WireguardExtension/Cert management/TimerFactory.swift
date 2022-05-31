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

protocol BackgroundTimerProtocol {
    mutating func invalidate()
}

protocol TimerFactory {
    func scheduledTimer(runAt nextRunTime: Date,
                        repeating: Double?,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimerProtocol

    func scheduleAfter(seconds: Int,
                       on queue: DispatchQueue,
                       _ closure: @escaping (() -> Void))
}

extension TimerFactory {
    func scheduledTimer(runAt nextRunTime: Date,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimerProtocol {
        scheduledTimer(runAt: nextRunTime, repeating: nil, queue: queue, closure)
    }
}

final class TimerFactoryImplementation: TimerFactory {
    func scheduledTimer(runAt nextRunTime: Date,
                        repeating: Double?,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimerProtocol {
        BackgroundTimer(runAt: nextRunTime, repeating: repeating, queue: queue, closure)
    }

    func scheduleAfter(seconds: Int, on queue: DispatchQueue, _ closure: @escaping (() -> Void)) {
        queue.asyncAfter(deadline: .now() + .seconds(seconds), execute: closure)
    }
}

final class BackgroundTimer: BackgroundTimerProtocol {
    private static let repeatingTimerLeewayInSeconds = 10

    private let timerSource: DispatchSourceTimer
    private let closure: () -> Void

    init(runAt nextRunTime: Date, repeating: Double?, queue: DispatchQueue, _ closure: @escaping () -> Void) {
        self.closure = closure
        timerSource = DispatchSource.makeTimerSource(queue: queue)

        if let repeating = repeating {
            timerSource.schedule(deadline: .now() + .seconds(Int(nextRunTime.timeIntervalSinceNow)),
                                 repeating: repeating,
                                 leeway: .seconds(Self.repeatingTimerLeewayInSeconds))
        } else {
            timerSource.schedule(deadline: .now() + .seconds(Int(nextRunTime.timeIntervalSinceNow)))
        }

        timerSource.setEventHandler { [weak self] in
            self?.closure()
        }
        timerSource.resume()
    }

    func invalidate() {
        timerSource.setEventHandler {}
        timerSource.cancel()
    }

    deinit {
        invalidate()
    }
}
