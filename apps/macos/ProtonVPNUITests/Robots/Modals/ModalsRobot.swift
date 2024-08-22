//
//  Created on 20/8/24.
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
import Modals

class ModalsRobot {
    
    let accessAllCountriesBanner = AllCountriesModal()
    
    func closeModal() -> ModalsRobot {
        app.dialogs.firstMatch.buttons["_XCUI:CloseWindow"].click()
        return self
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkModalAppear(type: ModalType) -> ModalsRobot {
            switch type {
            case .allCountries:
                ModalsRobot().accessAllCountriesBanner.verify.checkModalAppear()
            default:
                XCTAssertTrue(true == true)
            }
            return ModalsRobot()
        }
    }
    
    class AllCountriesModal {
        
        let verify = Verify()
        
        class Verify {
            
            func checkModalAppear() -> AllCountriesModal {
                let container = app.dialogs["Untitled"]
                
                XCTAssertTrue(container.waitForExistence(timeout: WaitTimeout.normal))
                
                let bannerTitle: String = container.staticTexts["TitleLabel"].firstMatch.value as? String ?? ""
                
                XCTAssertEqual(bannerTitle, Localizable.modalsNewUpsellAllCountriesTitle, "Banner title does not contain expected text '\(Localizable.modalsNewUpsellAllCountriesTitle)'. Actual message: \(bannerTitle)")
                
                let bannerDescription: String = container.staticTexts["DescriptionLabel"].firstMatch.value as? String ?? ""
                
                XCTAssertTrue(bannerDescription.contains("VPN Plus"), "Banner description does not contain expected text 'VPN Plus'. Actual message: \(bannerDescription)")
                
                XCTAssertTrue(container.buttons["ModalUpgradeButton"].waitForExistence(timeout: WaitTimeout.short), "ModalUpgradeButton does not appear at the AccessAllCountriesBanner")
                
                return AllCountriesModal()
            }
        }
    }
}
