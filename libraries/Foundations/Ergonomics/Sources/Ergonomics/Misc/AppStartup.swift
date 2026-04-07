//
//  Created on 09/03/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Collection of utilities to retrieve various informations about app startup.
public enum AppStartup {
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
}
