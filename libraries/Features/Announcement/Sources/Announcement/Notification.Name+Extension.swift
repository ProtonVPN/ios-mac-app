//
//  Created on 2025-01-31.
//
//  Copyright (c) 2025 Proton AG
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

public extension Notification.Name {
    /// A user was displayed a announcement.
    static let userWasDisplayedAnnouncement: Self = .init("UserWasDisplayedAnnouncement")
    /// A user was redirected to a payment portal through a notification.
    static let userEngagedWithAnnouncement: Self = .init("UserEngagedWithAnnouncement")
}
