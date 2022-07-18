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

public protocol BackgroundTimer {
    var isValid: Bool { get }
    mutating func invalidate()
}

public protocol TimerFactory {
    func scheduledTimer(runAt nextRunTime: Date,
                        repeating: Double?,
                        leeway: DispatchTimeInterval?,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimer

    func scheduleAfter(_ interval: DispatchTimeInterval,
                       on queue: DispatchQueue,
                       _ closure: @escaping (() -> Void))
}

extension TimerFactory {
    func scheduledTimer(timeInterval: TimeInterval,
                        repeats: Bool,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimer {
        scheduledTimer(runAt: Date().addingTimeInterval(timeInterval),
                       repeating: repeats ? timeInterval : nil,
                       queue: queue,
                       closure)
    }

    func scheduledTimer(runAt nextRunTime: Date,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimer {
        scheduledTimer(runAt: nextRunTime, repeating: nil, leeway: nil, queue: queue, closure)
    }

    func scheduledTimer(runAt nextRunTime: Date,
                        repeating: Double?,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimer {
        scheduledTimer(runAt: nextRunTime, repeating: repeating, leeway: nil, queue: queue, closure)
    }

    func scheduledTimer(runAt nextRunTime: Date,
                        leeway: DispatchTimeInterval?,
                        queue: DispatchQueue,
                        _ closure: @escaping (() -> Void)) -> BackgroundTimer {
        scheduledTimer(runAt: nextRunTime, repeating: nil, leeway: leeway, queue: queue, closure)
    }
}

public final class TimerFactoryImplementation: TimerFactory {
    public func scheduledTimer(runAt nextRunTime: Date,
                               repeating: Double?,
                               leeway: DispatchTimeInterval?,
                               queue: DispatchQueue,
                               _ closure: @escaping (() -> Void)) -> BackgroundTimer {
        BackgroundTimerImplementation(runAt: nextRunTime, repeating: repeating, leeway: leeway, queue: queue, closure)
    }

    public func scheduleAfter(_ interval: DispatchTimeInterval,
                              on queue: DispatchQueue,
                              _ closure: @escaping (() -> Void)) {
        queue.asyncAfter(deadline: .now() + interval, execute: closure)
    }

    public init() { }
}

public final class BackgroundTimerImplementation: BackgroundTimer {
    private static let repeatingTimerLeeway: DispatchTimeInterval = .seconds(10)

    private let timerSource: DispatchSourceTimer
    private let closure: () -> Void

    public var isValid: Bool

    init(runAt nextRunTime: Date,
         repeating: Double?,
         leeway: DispatchTimeInterval?,
         queue: DispatchQueue,
         _ closure: @escaping () -> Void) {
        self.closure = closure
        timerSource = DispatchSource.makeTimerSource(queue: queue)

        if let repeating = repeating {
            timerSource.schedule(deadline: .now() + nextRunTime.timeIntervalSinceNow,
                                 repeating: repeating,
                                 leeway: leeway ?? Self.repeatingTimerLeeway)
        } else {
            timerSource.schedule(deadline: .now() + nextRunTime.timeIntervalSinceNow)
        }

        isValid = true
        timerSource.setEventHandler { [weak self] in
            self?.closure()
        }
        timerSource.resume()
    }

    public func invalidate() {
        timerSource.setEventHandler {}
        timerSource.cancel()
        isValid = false
    }

    deinit {
        invalidate()
    }
}
