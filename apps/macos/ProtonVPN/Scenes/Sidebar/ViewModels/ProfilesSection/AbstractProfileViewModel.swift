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

import Foundation
import Dependencies
import LegacyCommon

class AbstractProfileViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    let profile: Profile
    let lowestServerTier: Int
    let userTier: Int
    let underMaintenance: Bool
    
    init(profile: Profile, userTier: Int) {
        self.profile = profile
        self.userTier = userTier
        
        switch profile.serverOffering {
        case .custom(let serverWrapper):
            self.lowestServerTier = serverWrapper.server.tier
            self.underMaintenance = serverWrapper.server.underMaintenance

        case .fastest(let countryCode), .random(let countryCode):
            guard let code = countryCode else {
                self.lowestServerTier = 0
                self.underMaintenance = false
                break
            }
            
            let serverManager = ServerManagerImplementation.instance(forTier: .paidTier, serverStorage: ServerStorageConcrete())
            
            var minTier = Int.max
            var allServersUnderMaintenance = true
            let serversOfProfileType = serverManager.grouping(for: profile.serverType)
            let serversOfProfileTypeAndCountry = serversOfProfileType.first { group -> Bool in
                return group.serverOfferingId == code
            }?.servers
            serversOfProfileTypeAndCountry?.forEach { (server) in
                if minTier > server.tier {
                    minTier = server.tier
                }
                if !server.underMaintenance {
                    allServersUnderMaintenance = false
                }
            }
            self.lowestServerTier = minTier
            self.underMaintenance = allServersUnderMaintenance
        }
    }

    var canUseProfile: Bool { authorizer.canUseProfile(ofTier: lowestServerTier) }
    
    var alphaOfMainElements: CGFloat {
        return canUseProfile ? 1.0 : 0.5
    }
    
}
