//
//  Created on 30/04/2024.
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
import CommonNetworking

extension DoHVPN {
    /// Default implementation of checking whether a `Notification` contains an `AppState` and whether its in the
    /// connected state. This has been crudely extracted out of the DoH implementation to remove the dependency on
    /// `LegacyCommon.AppState`, until we have a better place to move `AppState` to.
    public static func isAppStateChangeNotificationInConnectedState(notification: Notification) -> Bool {
        guard let state = notification.object as? AppState else {
            log.error("Notification object is not an `AppState`")
            return false
        }
        if case .connected = state {
            return true
        } else {
            return false
        }
    }
}
