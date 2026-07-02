//
//  GeneralSettingsViewModel.swift
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
import Foundation
import LegacyCommon
import Sharing
import VPNAppCore

final class GeneralSettingsViewModel {
    init() {}

    @Shared(.startOnBoot) var startOnBoot
    @Shared(.startMinimized) var startMinimized
    @Shared(.systemNotifications) var systemNotifications
    @Shared(.unprotectedNetworkNotifications) var unprotectedNetworkNotifications
    @Shared(.earlyAccess) var earlyAccess: Bool

    // MARK: - Setters

    func setStartOnBoot(_ enabled: Bool) {
        ProtonVPN.setStartOnBoot(enabled)
    }

    func setStartMinimized(_ enabled: Bool) {
        $startMinimized.withLock { $0 = enabled }
    }

    func setSystemNotifications(_ enabled: Bool) {
        $systemNotifications.withLock { $0 = enabled }
    }

    func setEarlyAccess(_ enabled: Bool) {
        $earlyAccess.withLock { $0 = enabled }
    }

    func setUnprotectedNetworkNotifications(_ enabled: Bool) {
        $unprotectedNetworkNotifications.withLock { $0 = enabled }
    }
}
