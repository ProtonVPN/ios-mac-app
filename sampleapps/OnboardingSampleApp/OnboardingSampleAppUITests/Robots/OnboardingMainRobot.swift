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

fileprivate let onboarding = "StartButton"
fileprivate let takeATourButton = "TakeATourButton"
fileprivate let welcomeTitle = "WelcomeTitle"
fileprivate let welcomeDescription = "WelcomeSubtitle"
fileprivate let skipButton = "SkipButton"

class OnboardingMainRobot {
    let app: XCUIApplication
    let verify: Verify

    init(app: XCUIApplication) {
        self.app = app
        self.verify = Verify(app: app)
    }
    
    func startOnboarding() -> OnboardingMainRobot {
        app.buttons[onboarding].tap()
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
        func onboardingScreen() -> OnboardingMainRobot {
            XCTAssert(app.buttons[onboarding].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[onboarding].exists)
            return OnboardingMainRobot(app: app)
        }
    }
}
