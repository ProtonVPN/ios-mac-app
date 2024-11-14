//
//  Created on 29/9/22.
//
//  Copyright (c) 2022 Proton AG
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
import fusion
import ProtonCoreTestingToolkitUITestsPaymentsUI
import Strings

fileprivate let manageSubscriptionButton = Localizable.manageSubscription
fileprivate let upgradeSubscriptionButton = Localizable.upgradeSubscription
fileprivate let deleteAccountText = "Delete account"
fileprivate let deleteButton = Localizable.delete
fileprivate let selectedEnvHeader = "Selected environment"

class AccountRobot: CoreElements {

    @discardableResult
    func goToManageSubscription() -> SubscriptionsRobot {
        button(manageSubscriptionButton).tap()
        return SubscriptionsRobot()
    }

    @discardableResult
    func goToUpgradeSubscription() -> SubscriptionsRobot {
        button(upgradeSubscriptionButton).tap()
        return SubscriptionsRobot()
    }
    
    func deleteAccount() -> AccountRobot {
        button(deleteAccountText).tap()
        return AccountRobot()
    }

    @discardableResult
    func tapSubscription() -> PaymentsUIRobot {
        button(upgradeSubscriptionButton).tap()
        return PaymentsUIRobot()
    }

    let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func deleteAccountScreen() -> AccountRobot {
            staticText(deleteAccountText).waitUntilExists(time: 12).checkExists()
            button(deleteButton).waitUntilExists(time: 12).checkExists()
            return AccountRobot()
        }
        
        @discardableResult
        func userIsLoggedOut() -> AccountRobot {
            staticText(selectedEnvHeader).waitUntilExists(time: 5).checkExists()
            return AccountRobot()
        }
    }
}
