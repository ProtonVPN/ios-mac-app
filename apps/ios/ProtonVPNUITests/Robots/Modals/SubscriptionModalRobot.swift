//
//  Created on 7/11/24.
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

import Strings
import fusion

fileprivate let upsellPlansListTitle = Localizable.upsellPlansListTitle
fileprivate let upsellPlansListValidateButton = Localizable.upsellPlansListValidateButton
fileprivate let upsellPlansListSectionHeader = Localizable.upsellPlansListSectionHeader

class SubscriptionModalRobot: ModalRobot {
    
    public let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func subscriptionModalIsShown() -> SubscriptionModalRobot {
            staticText(upsellPlansListTitle).checkExists()
            button(upsellPlansListValidateButton).checkExists()
            staticText(upsellPlansListSectionHeader).checkExists()
            return SubscriptionModalRobot()
        }
        
        @discardableResult
        public func verifyPlanOptions(planDuration: String, planAmount: String) -> SubscriptionModalRobot {
            staticText("plan_option_duration").firstMatch()
                .checkExists(message: "Plan option element plan_option_duration not found")
                .hasLabel(planDuration)
            
            staticText("plan_option_amount").firstMatch()
                .checkExists(message: "Plan option element plan_option_amount not found")
                .hasLabel(planAmount)
            return SubscriptionModalRobot()
            
        }
    }
}
