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
fileprivate let slideOneDescription = "Proton VPN supports all devices, including Windows, macOS, and many others."
fileprivate let slideTwoTitle = "Unblock streaming"
fileprivate let slideTwoDescription = "Secure access to your favorite content from other countries — Now available on Android TV."
fileprivate let slideThreeTitle = "Block ads and much more"
fileprivate let slideThreeDescription = "Block malware, ads, and trackers in browser and in all apps."
fileprivate let slideFourTitle = "Help us fight censorship"
fileprivate let slideFifthTitle = "No logs and Swiss-based"
fileprivate let skipButton = "SkipButton"
fileprivate let nextButton = "Next"

class OnboardingSlidesRobot {
    let app: XCUIApplication
    let verify: Verify

    init(app: XCUIApplication) {
        self.app = app
        self.verify = Verify(app: app)
    }
    
    func nextOnboardingScreen() -> OnboardingSlidesRobot {
        app.buttons[nextButton].tap()
        return OnboardingSlidesRobot(app: app)
    }
    
    func nextStepA() -> OnboardingConnectionRobot {
        app.buttons[nextButton].tap()
        return OnboardingConnectionRobot(app: app)
    }
    
    func nextStepB() -> OnboardingPaymentRobot {
        app.buttons[nextButton].tap()
        return OnboardingPaymentRobot(app: app)
    }    
    
    class Verify {
        let app: XCUIApplication

        init(app: XCUIApplication) {
            self.app = app
        }

        @discardableResult
        func onboardingFirstSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssert(app.staticTexts[slideOneTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[slideOneDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].firstMatch.isEnabled)
            return OnboardingSlidesRobot(app: app)
        }
        
        @discardableResult
        func onboardingSecondSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssert(app.staticTexts[slideTwoTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[slideTwoDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingSlidesRobot(app: app)
        }

        @discardableResult
        func onboardingThirdSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssert(app.staticTexts[slideThreeTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[slideThreeDescription].exists)
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingSlidesRobot(app: app)
        }

        @discardableResult
        func onboardingFourSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssert(app.staticTexts[slideFourTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            return OnboardingSlidesRobot(app: app)
        }

        @discardableResult
        func onboardingFifthSlideIsShown() -> OnboardingSlidesRobot {
            XCTAssert(app.staticTexts[slideFifthTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[nextButton].isEnabled)
            return OnboardingSlidesRobot(app: app)
        }
    }
}
