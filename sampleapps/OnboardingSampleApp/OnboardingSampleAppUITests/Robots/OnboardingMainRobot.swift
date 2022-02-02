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

import Foundation
import XCTest

fileprivate let onboardingA = "StartAButton"
fileprivate let onboardingB = "StartBButton"
fileprivate let takeATourButton = "Take a tour"
fileprivate let welcomeTitle = "Welcome to ProtonVPN"
fileprivate let welcomeDescription = "Learn how to get the most out of ProtonVPN in just a few seconds"
fileprivate let skipButton = "SkipButton"

class OnboardingMainRobot {
    let app: XCUIApplication
    let verify: Verify

    init(app: XCUIApplication) {
        self.app = app
        self.verify = Verify(app: app)
    }
    
    func startOnboardingA() -> OnboardingMainRobot {
        app.buttons[onboardingA].tap()
        return OnboardingMainRobot(app: app)
    }
    
    func startOnboardingB() -> OnboardingMainRobot {
        app.buttons[onboardingB].tap()
        return OnboardingMainRobot(app: app)
    }
    
    func startUserOnboarding() -> OnboardingSlidesRobot {
        app.buttons[takeATourButton].tap()
        return OnboardingSlidesRobot(app: app)
    }
    
    class Verify {
        let app: XCUIApplication

        init(app: XCUIApplication) {
            self.app = app
        }
        
        @discardableResult
        func welcomeScreenIsShown() -> OnboardingMainRobot {
            XCTAssert(app.staticTexts[welcomeTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[welcomeDescription].exists)
            XCTAssertTrue(app.buttons[takeATourButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingMainRobot(app: app)
        }
        
        @discardableResult
        func onboardingABScreen() -> OnboardingMainRobot {
            XCTAssert(app.buttons[onboardingA].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[onboardingA].exists)
            return OnboardingMainRobot(app: app)
        }
    }
}
