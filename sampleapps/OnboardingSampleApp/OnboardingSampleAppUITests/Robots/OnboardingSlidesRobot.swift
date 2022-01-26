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

fileprivate let slideOneTitle = "Be protected everywhere"
fileprivate let slideOneDescription = "ProtonVPN supports all devices, including Windows, macOS, and many others."
fileprivate let slideTwoTitle = "Unblock streaming"
fileprivate let slideTwoDescription = "Secure access your favourite content from other countries, now also on AndroidTV."
fileprivate let slideThreeTitle = "Block ads and much more"
fileprivate let slideThreeDescription = "Block malware, ads, and trackers in browser and in all apps."
fileprivate let skipButton = "Skip"
fileprivate let nextButton = "Next"

class OnboardingSlidesRobot {
    
    func nextOnboardingScreen() -> OnboardingSlidesRobot {
        app.buttons[nextButton].tap()
        return OnboardingSlidesRobot() 
    }
    
    func nextStepA() -> OnboardingConnectionRobot {
        app.buttons[nextButton].tap()
        return OnboardingConnectionRobot()
    }
    
    func nextStepB() -> OnboardingPaymentRobot {
        app.buttons[nextButton].tap()
        return OnboardingPaymentRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func onboardingFirstSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssertTrue(app.staticTexts[slideOneTitle].exists)
            XCTAssertTrue(app.staticTexts[slideOneDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].firstMatch.isEnabled)
            return OnboardingSlidesRobot()
        }
        
        @discardableResult
        func onboardingSecondSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssertTrue(app.staticTexts[slideTwoTitle].exists)
            XCTAssertTrue(app.staticTexts[slideTwoDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingSlidesRobot()
        }
        
        @discardableResult
        func onboardingThirdSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssertTrue(app.staticTexts[slideThreeTitle].exists)
            XCTAssertTrue(app.staticTexts[slideThreeDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingSlidesRobot()
        }
    }
}
