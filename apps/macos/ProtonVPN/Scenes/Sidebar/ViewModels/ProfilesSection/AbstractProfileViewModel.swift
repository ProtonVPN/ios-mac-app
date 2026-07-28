//
//  AbstractProfileViewModel.swift
//  ProtonVPN - Created on 05/09/2019.
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
import Persistence
import VPNAppCore

class AbstractProfileViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    let profile: Profile
    let lowestServerTier: VpnTier
    let userTier: VpnTier
    let underMaintenance: Bool

    init(profile: Profile, userTier: VpnTier) {
        self.profile = profile
        self.userTier = userTier

        @Dependency(\.serverRepository) var serverRepository
        let serverAvailability = serverRepository.serverAvailability(for: profile)
        self.lowestServerTier = serverAvailability.lowestServerTier
        self.underMaintenance = serverAvailability.isUnderMaintenance
    }

    var canUseProfile: Bool {
        authorizer.canUseProfile(ofTier: lowestServerTier)
    }

    var alphaOfMainElements: CGFloat {
        canUseProfile ? 1.0 : 0.5
    }
}
