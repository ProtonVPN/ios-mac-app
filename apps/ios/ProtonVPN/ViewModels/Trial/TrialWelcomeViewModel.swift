//
//  TrialWelcomeViewModel.swift
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

import UIKit
import vpncore

struct TrialWelcomeViewModel {
    
    private let expiration: Date
    private let planService: PlanService
    private let planChecker: PlanUpgradeCheckerProtocol
    
    init(expiration: Date, planService: PlanService, planChecker: PlanUpgradeCheckerProtocol) {
        self.expiration = expiration
        self.planService = planService
        self.planChecker = planChecker
    }
    
    func timeRemainingAttributedString() -> NSAttributedString {
        var displayExpiration = expiration
        if expiration.timeIntervalSince1970 < 0.1 { // trial not yet started
            displayExpiration = Date(timeInterval: 60 * 60 * 24 * 7 + 0.5, since: Date())
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .pad
        let timeRemainingString = formatter.string(from: displayExpiration.timeIntervalSinceNow)!
        
        return timeRemainingString.attributed(withColor: .protonWhite(), fontSize: 17, alignment: .center)
    }
    
    func cancelButtonTitle() -> String {
        return canUpgrade() ? LocalizedString.maybeLater : LocalizedString.gotIt
    }
    
    func canUpgrade() -> Bool {
        return planChecker.canUpgrade()
    }
    
    func selectUpgrade() {
        planService.presentPlanSelection() 
    }
}
