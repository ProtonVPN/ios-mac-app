//
//  Created on 19/8/24.
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
import Strings
import XCTest
import fusion
import UITestsHelpers

let app = XCUIApplication()

class AlertRobot: CoreElements {
    
    let logoutWarningAlert = LogoutWarningAlert()

    let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func checkLogoutWarningAlertAppear() -> AlertRobot {
            AlertRobot().logoutWarningAlert.verify.checkAlertAppear()
            return AlertRobot()
        }
    }
    
    class LogoutWarningAlert: CoreElements {
        private lazy var alertContainer = dialog(Localizable.vpnConnectionActive)
        
        func clickContinue() -> LogoutWarningAlert {
            button(Localizable.continue).tap()
            return self
        }
        
        func clickCancel() -> LogoutWarningAlert {
            alertContainer.onChild(button(Localizable.cancel)).tap()
            
            return self
        }
        
        func isVisible() -> Bool {
            return alertContainer.waitUntilExists(time: 0.5).exists()
        }
        
        let verify = Verify()
        
        class Verify: CoreElements {
            
            func checkAlertAppear() -> LogoutWarningAlert {
                let container = LogoutWarningAlert().alertContainer
                
                container.waitUntilExists(time: WaitTimeout.normal).checkExists()
                container.onChild(staticText(Localizable.logOutWarningLong)).checkExists()
                
                return LogoutWarningAlert()
            }
        }
    }
}
