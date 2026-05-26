//
//  Created on 14/05/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import Foundation

public extension DependencyValues {
    /// Indicates whether the app process was launched as a login item.
    ///
    /// App targets can override this for platform-specific startup behavior.
    var wasLaunchedAtLogin: @Sendable () -> Bool {
        get { self[LaunchModeKey.self] }
        set { self[LaunchModeKey.self] = newValue }
    }

    /// Process start date to support startup grace periods in platform-specific flows.
    var appProcessStartDate: @Sendable () -> Date? {
        get { self[AppProcessStartDateKey.self] }
        set { self[AppProcessStartDateKey.self] = newValue }
    }
}

private enum LaunchModeKey: DependencyKey {
    static let liveValue: @Sendable () -> Bool = { false }
    static let testValue: @Sendable () -> Bool = { false }
}

private enum AppProcessStartDateKey: DependencyKey {
    static let liveValue: @Sendable () -> Date? = { nil }
    static let testValue: @Sendable () -> Date? = { nil }
}
