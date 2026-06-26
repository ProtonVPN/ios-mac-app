//
//  Created on 26/06/2026 by Max Kupetskyi.
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

import Dependencies
import DependenciesMacros

/// Presents local, non-modal notifications to the user (system notifications on macOS, toasts on iOS)
@DependencyClient
public struct NotificationManager {
    /// Notifies the user that the server they are connected to is going on maintenance.
    public var displayServerGoingOnMaintenance: () -> Void
    /// Notifies the user that the forwarded port changed. macOS only; no-op on iOS.
    public var displayPFChange: (_ portNumber: UInt16) -> Void
    /// Notifies the user that port forwarding failed. macOS only; no-op on iOS.
    public var displayPFError: () -> Void
}

extension NotificationManager: TestDependencyKey {
    public static let testValue = NotificationManager()
}

public extension DependencyValues {
    var notificationManager: NotificationManager {
        get { self[NotificationManager.self] }
        set { self[NotificationManager.self] = newValue }
    }
}
