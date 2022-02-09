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

fileprivate let establishConnectionTitle = "OnboardingEstablishTitle"
fileprivate let establishConnectionSubtitle = "OnboardingEstablishSubtitle"
fileprivate let establishConnectionDescription = "OnboardingEstablishNote"
fileprivate let connectNowButton = "Connect now"
fileprivate let purchasePlusButton = "PurchasePlusButton"
fileprivate let skipButton = "SkipButton"
fileprivate let connectionTitle = "CongratulationsTitle"
fileprivate let connectionDescription = "CongratulationsSubtitle"
fileprivate let connectedTo = "ConnectedToLabel"
fileprivate let continueButton = "DoneButton"
fileprivate let getPlusButton = "GetPlusButton"

class OnboardingConnectionRobot {
    let app: XCUIApplication
    let verify: Verify

    init(app: XCUIApplication) {
        self.app = app
        self.verify = Verify(app: app)
    }
    
    func connectNow() -> OnboardingConnectionRobot {
        app.buttons[connectNowButton].tap()
        return OnboardingConnectionRobot(app: app)
    }

    func accessAllCountries() -> OnboardingConnectionRobot {
        app.buttons[purchasePlusButton].tap()
        return OnboardingConnectionRobot(app: app)
    }
    
    func nextStepA() -> OnboardingPaymentRobot {
        app.buttons[continueButton].tap()
        return OnboardingPaymentRobot(app: app)
    }
    
    func nextStepB() -> OnboardingMainRobot {
        app.buttons[continueButton].tap()
        return OnboardingMainRobot(app: app)
    }
    
    class Verify {
        let app: XCUIApplication

        init(app: XCUIApplication) {
            self.app = app
        }

        func establichConnectionScreenIsShown() -> OnboardingConnectionRobot {
            XCTAssert(app.staticTexts[establishConnectionTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[establishConnectionSubtitle].exists)
            XCTAssertTrue(app.staticTexts[establishConnectionDescription].exists)
            XCTAssertTrue(app.buttons[connectNowButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].firstMatch.isEnabled)
            XCTAssertTrue(app.buttons[purchasePlusButton].isEnabled)
            return OnboardingConnectionRobot(app: app)
        }
        
        func connectionScreenIsShown() -> OnboardingConnectionRobot {
            XCTAssert(app.staticTexts[connectionTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[connectionDescription].exists)
            XCTAssertTrue(app.staticTexts[connectedTo].exists)
            XCTAssertTrue(app.buttons[continueButton].isEnabled)
            return OnboardingConnectionRobot(app: app)
        }
    }
}
