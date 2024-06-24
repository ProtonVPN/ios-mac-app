//
//  Created on 11/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

#if os(macOS)
import Foundation

/// Collection of utilities to retrieve various informations about app startup.
public enum AppStartup {
    public private(set) static var isLaunchedAtLogin: Bool = false

    /// The date at which the process was launched, either at user login or not.
    public static var processStartDate: Date? {
        let pid = ProcessInfo.processInfo.processIdentifier
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var proc: kinfo_proc = .init()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&mib, UInt32(mib.count), &proc, &size, nil, 0) == 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(proc.kp_proc.p_starttime.tv_sec))
    }

    /// Call this as soon as possible when app is launched in order set ``isLaunchedAtLogin``.
    public static func processStartAppleEvent() {
        isLaunchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?.isOpenAppLoginItemLaunchEvent == true
        log.info("App is launched at login: \(isLaunchedAtLogin)", category: .app)
    }
}

extension NSAppleEventDescriptor {
    var isOpenEvent: Bool {
        return eventClass == kCoreEventClass && eventID == kAEOpenApplication
    }

    var isOpenAppLoginItemLaunchEvent: Bool {
        guard isOpenEvent else { return false }
        return paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
#endif
