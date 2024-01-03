//
//  Created on 29/03/2023.
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

import Foundation

#if canImport(UIKit)
import UIKit
struct Notifications {
    public static let shouldResume = UIApplication.didBecomeActiveNotification
    public static let shouldSuspend = UIApplication.willResignActiveNotification
}
#elseif canImport(AppKit)
import AppKit
import Cocoa
struct Notifications {
    public static let shouldResume = NSApplication.willBecomeActiveNotification
    public static let shouldSuspend = NSApplication.willResignActiveNotification
}
#endif

/// Timer implementation that is paused while the application is in the background
public class ForegroundTimerImplementation: BackgroundTimerImplementation {
    override init(
        runAt nextRunTime: Date,
        repeating: Double?,
        leeway: DispatchTimeInterval?,
        queue: DispatchQueue,
        _ closure: @escaping () -> Void
    ) {
        super.init(runAt: nextRunTime, repeating: repeating, leeway: leeway, queue: queue, closure)

        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: Notifications.shouldResume, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(suspend), name: Notifications.shouldSuspend, object: nil)
    }
}

public class ForegroundTimerFactoryImplementation: TimerFactoryImplementation {
    override public func scheduledTimer(
        runAt nextRunTime: Date,
        repeating: Double?,
        leeway: DispatchTimeInterval?,
        queue: DispatchQueue,
        _ closure: @escaping (() -> Void)
    ) -> BackgroundTimer {
        ForegroundTimerImplementation(runAt: nextRunTime, repeating: repeating, leeway: leeway, queue: queue, closure)
    }
}
