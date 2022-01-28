//
//  Created on 2022-01-26.
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

import XCTest

fileprivate let plusFeature = "Access all 1300+ servers in 61 countries with Plus"
fileprivate let getPlusButton = "GetPlusButton"
fileprivate let useFreePlanButton = "UseFreeButton"
fileprivate let closeButton = "CloseButton"
fileprivate let plusPurchased = "PlanPurchaseButton"
fileprivate let congratulationsTitle = "Congratulations"
fileprivate let congratulationsDescription = "You now have access to 1300+ secure servers and other premium features."
fileprivate let connectButton = "ConnectToPlusServerButton"
fileprivate let skipButton = "SkipButton"

class OnboardingPaymentRobot {
    
    func getPlus() -> OnboardingPaymentRobot {
        app.buttons[getPlusButton].tap()
        return OnboardingPaymentRobot()
    }
    
    func useFreePlanA() -> OnboardingMainRobot {
        app.buttons[useFreePlanButton].tap()
        return OnboardingMainRobot()
    }
    
    func useFreePlanB() -> OnboardingConnectionRobot {
        app.buttons[useFreePlanButton].tap()
        return OnboardingConnectionRobot()
    }
    
    func plusPlanIsPurchased() -> OnboardingPaymentRobot {
        app.buttons[plusPurchased].tap()
        return OnboardingPaymentRobot()
    }
    
    func connectToAPlusServer() -> OnboardingMainRobot {
        app.buttons[connectButton].tap()
        return OnboardingMainRobot()
    }

    func skip() -> OnboardingMainRobot {
        app.buttons[skipButton].tap()
        return OnboardingMainRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func accessAllCountriesScreenIsShown() -> OnboardingPaymentRobot {
            XCTAssertTrue(app.staticTexts[plusFeature].exists)
            XCTAssertTrue(app.buttons[getPlusButton].isEnabled)
            XCTAssertTrue(app.buttons[useFreePlanButton].isEnabled)
            XCTAssertTrue(app.buttons[closeButton].isEnabled)
            return OnboardingPaymentRobot()
        }
        
        @discardableResult
        func congratulationsScreenIsShown() -> OnboardingPaymentRobot {
            XCTAssertTrue(app.staticTexts[congratulationsTitle].exists)
            XCTAssertTrue(app.staticTexts[congratulationsDescription].exists)
            XCTAssertTrue(app.buttons[connectButton].isEnabled)
            return OnboardingPaymentRobot()
        }
    }
}
