//
//  PlanUpgradeChecker.swift
//  ProtonVPN - Created on 01.07.19.
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
import vpncore

public protocol PlanUpgradeCheckerProtocol {
    
    func canUpgrade() -> Bool
    
}

public class PlanUpgradeChecker: PlanUpgradeCheckerProtocol {
    
    private let vpnKeychain: VpnKeychainProtocol
    
    init(vpnKeychain: VpnKeychainProtocol) {
        self.vpnKeychain = vpnKeychain
    }
    
    public func canUpgrade() -> Bool {
        let propertiesManager = PropertiesManager()
        
        if let authCredentials = AuthKeychain.fetch(), let vpnCredentials = try? vpnKeychain.fetch(), !vpnCredentials.accountPlan.paid && authCredentials.scopes.contains(.payments) && propertiesManager.isIAPUpgradePlanAvailable && propertiesManager.currentSubscription?.hasExistingProtonSubscription == false {
            return true
        } else {
            return false
        }
    }
    
}
