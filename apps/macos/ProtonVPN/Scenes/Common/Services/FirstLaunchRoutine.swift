//
//  FirstLaunchRoutine.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Dependencies
import Domain
import Foundation
import LegacyCommon
import Sharing
import VPNShared

class AppLaunchRoutine {
    static var launchedBefore = true

    static func execute() {
        @Shared(.launchedBefore) var launchedBefore
        if !launchedBefore {
            Self.launchedBefore = false
            setStartOnBoot(false)
            @Shared(.startMinimized) var startMinimized
            $startMinimized.withLock { $0 = false }
            @Shared(.hasConnected) var hasConnected
            $hasConnected.withLock { $0 = false }
            @Shared(.systemNotifications) var systemNotifications
            $systemNotifications.withLock { $0 = true }
            $launchedBefore.withLock { $0 = true }
        }
    }
}
