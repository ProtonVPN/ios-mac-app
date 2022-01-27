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

let app = XCUIApplication()

fileprivate let onboardingA = "StartAButton"
fileprivate let onboardingB = "StartBButton"
fileprivate let takeATourButton = "Take a tour"
fileprivate let welcomeTitle = "Welcome to ProtonVPN"
fileprivate let welcomeDescription = "Learn how to get the most out of ProtonVPN in just a few seconds"
fileprivate let skipButton = "SkipButton"

class OnboardingMainRobot {
    
    func startOnboardingA() -> OnboardingMainRobot {
        app.buttons[onboardingA].tap()
        return OnboardingMainRobot()
    }
    
    func startOnboardingB() -> OnboardingMainRobot {
        app.buttons[onboardingB].tap()
        return OnboardingMainRobot()
    }
    
    func startUserOnboarding() -> OnboardingSlidesRobot {
        app.buttons[takeATourButton].tap()
        return OnboardingSlidesRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func welcomeScreenIsShown() -> OnboardingMainRobot {
            XCTAssertTrue(app.staticTexts[welcomeTitle].exists)
            XCTAssertTrue(app.staticTexts[welcomeDescription].exists)
            XCTAssertTrue(app.buttons[takeATourButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].isEnabled)
            return OnboardingMainRobot()
        }
        
        @discardableResult
        func onboardingABScreen() -> OnboardingMainRobot {
            XCTAssertTrue(app.buttons[onboardingA].exists)
            XCTAssertTrue(app.buttons[onboardingA].exists)
            return OnboardingMainRobot()
        }
    }
}
