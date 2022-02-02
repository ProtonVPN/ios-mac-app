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
    let app: XCUIApplication
    let verify: Verify

    init(app: XCUIApplication) {
        self.app = app
        self.verify = Verify(app: app)
    }

    func getPlus() -> OnboardingPaymentRobot {
        app.buttons[getPlusButton].tap()
        return OnboardingPaymentRobot(app: app)
    }
    
    func useFreePlanA() -> OnboardingMainRobot {
        app.buttons[useFreePlanButton].tap()
        return OnboardingMainRobot(app: app)
    }
    
    func useFreePlanB() -> OnboardingConnectionRobot {
        app.buttons[useFreePlanButton].tap()
        return OnboardingConnectionRobot(app: app)
    }
    
    func plusPlanIsPurchased() -> OnboardingPaymentRobot {
        app.buttons[plusPurchased].tap()
        return OnboardingPaymentRobot(app: app)
    }
    
    func connectToAPlusServer() -> OnboardingMainRobot {
        app.buttons[connectButton].tap()
        return OnboardingMainRobot(app: app)
    }

    func skip() -> OnboardingMainRobot {
        app.buttons[skipButton].tap()
        return OnboardingMainRobot(app: app)
    }
    
    class Verify {
        let app: XCUIApplication

        init(app: XCUIApplication) {
            self.app = app
        }

        @discardableResult
        func accessAllCountriesScreenIsShown() -> OnboardingPaymentRobot {
            XCTAssert(app.staticTexts[plusFeature].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[getPlusButton].isEnabled)
            XCTAssertTrue(app.buttons[useFreePlanButton].isEnabled)
            XCTAssertTrue(app.buttons[closeButton].isEnabled)
            return OnboardingPaymentRobot(app: app)
        }
        
        @discardableResult
        func congratulationsScreenIsShown() -> OnboardingPaymentRobot {
            XCTAssert(app.staticTexts[congratulationsTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[congratulationsDescription].exists)
            XCTAssertTrue(app.buttons[connectButton].isEnabled)
            return OnboardingPaymentRobot(app: app)
        }
    }
}
