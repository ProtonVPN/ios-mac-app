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
import fusion

class ModalsRobot: CoreElements {
    
    let accessAllCountriesBanner = AllCountriesModal()
    let cantSkipBanner = CantSkipBanner()
    
    func closeModal() -> ModalsRobot {
        dialog().firstMatch().onChild(button("_XCUI:CloseWindow")).tap()
        return self
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkModalAppear(type: ModalType) -> ModalsRobot {
            switch type {
            case .allCountries:
                return ModalsRobot().accessAllCountriesBanner.verify.checkModalAppear()
            case .cantSkip:
                return ModalsRobot().cantSkipBanner.verify.checkModalAppear()
            default:
                return ModalsRobot()
            }
        }
    }
    
    class AllCountriesModal {
        
        let verify = Verify()
        
        class Verify: CoreElements {
            
            func checkModalAppear() -> ModalsRobot {
                let container = dialog("Untitled")
                container.checkExists()
                container.onChild(staticText( Localizable.modalsNewUpsellAllCountriesTitle)).checkExists(message: "Banner title does not contain expected text '\(Localizable.modalsNewUpsellAllCountriesTitle)'")
                container.onChild(staticText(NSPredicate(format: "title CONTAINS[c] %@", "VPN Plus"))).checkExists(message: "Banner description does not contain expected text 'VPN Plus'")
                
                container.onChild(button("ModalUpgradeButton")).checkExists(message: "ModalUpgradeButton does not appear at the AccessAllCountriesBanner")
                
                return ModalsRobot()
            }
        }
    }
    
    class CantSkipBanner {
        let verify = Verify()
        
        class Verify: CoreElements {
            
            func checkModalAppear() -> ModalsRobot {
                let container = dialog("Untitled")
                container.checkExists()
                
                let bannerDescription: String = container.onChild(staticText("DescriptionLabel")).value() as? String ?? ""
                
                XCTAssertTrue(bannerDescription.contains(Localizable.upsellSpecificLocationSubtitle), "Banner description does not contain expected text '\(Localizable.upsellSpecificLocationSubtitle)'. Actual message: \(bannerDescription)")
                
                container.onChild(button("Upgrade")).checkExists(message: "Upgrade button does not appear at the AccessAllCountriesBanner")
                
                return ModalsRobot()
            }
        }
    }
}
