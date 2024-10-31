//
//  Created on 31.10.2024.
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

import Foundation

#if DEBUG
public struct UpdateCheckerMock: UpdateChecker {
    public func startUpdate() {
    }
    
    public func isUpdateAvailable() async -> Bool {
        return false
    }

    /// Check if the latest app supports the current running OS version.
    public func minimumVersionRequiredByNextUpdate() async -> OperatingSystemVersion {
        return ProcessInfo.processInfo.operatingSystemVersion
    }

    public init() {}
}
#endif
