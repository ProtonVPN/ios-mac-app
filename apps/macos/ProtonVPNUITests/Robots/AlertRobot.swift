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

let app = XCUIApplication()

class AlertRobot {
    
    let logoutWarningAlert = LogoutWarningAlert()

    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkLogoutWarningAlertAppear() -> AlertRobot {
            AlertRobot().logoutWarningAlert.verify.checkAlertAppear()
            return AlertRobot()
        }
    }
    
    class LogoutWarningAlert {
        let alertContainer = app.dialogs[Localizable.vpnConnectionActive]
        
        func clickContinue() -> LogoutWarningAlert {
            alertContainer.buttons[Localizable.continue].click()
            
            return self
        }
        
        func clickCancel() -> LogoutWarningAlert {
            alertContainer.buttons[Localizable.cancel].click()
            
            return self
        }
        
        func isVisible() -> Bool {
            return alertContainer.waitForExistence(timeout: WaitTimeout.short)
        }
        
        let verify = Verify()
        
        class Verify {
            
            func checkAlertAppear() -> LogoutWarningAlert {
                let container = LogoutWarningAlert().alertContainer
                
                XCTAssertTrue(container.waitForExistence(timeout: WaitTimeout.normal))
                
                let dialogMessage: String = container.textViews.firstMatch.value as? String ?? ""
                XCTAssert(dialogMessage.contains(Localizable.logOutWarningLong), "Alert message does not contain expected text '\(Localizable.quitWarning)'. Actual message: \(dialogMessage)")
                
                return LogoutWarningAlert()
            }
        }
    }
}
