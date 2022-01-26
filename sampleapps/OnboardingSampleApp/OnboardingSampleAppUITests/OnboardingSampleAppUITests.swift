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

class OnboardingSampleAppBaseTestCase: XCTestCase {

    let app = XCUIApplication()
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private let onboardingMainRobot = OnboardingMainRobot()
    
    func testStartOnboardingAConnectNowAndGetPlus() {
        
        onboardingMainRobot
            .startOnboardingA()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextStepA()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepA()
            .verify.accessAllCountriesScreenIsShown()
            .getPlus()
            .plusPlanIsPurchased()
            .verify.congratulationsScreenIsShown()
            .connectToAPlusServer()
            .verify.onboardingABScreen()
    }
    
    func testStartOnboardingAConnectNowFreePlan() {
        
        onboardingMainRobot
            .startOnboardingA()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextStepA()
            .verify.establichConnectionScreenIsShown()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepA()
            .verify.accessAllCountriesScreenIsShown()
            .useFreePlanA()
            .verify.onboardingABScreen()
    }
    
    func testStartOnboardingBConnectNowAndGetPlus() {
        
        onboardingMainRobot
            .startOnboardingB()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextStepB()
            .verify.accessAllCountriesScreenIsShown()
            .getPlus()
            .plusPlanIsPurchased()
            .verify.congratulationsScreenIsShown()
            .connectToAPlusServer()
            .verify.onboardingABScreen()
    }
    
    func testStartOnboardingBConnectNowFreePlan() {
        
        onboardingMainRobot
            .startOnboardingB()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextStepB()
            .verify.accessAllCountriesScreenIsShown()
            .useFreePlanB()
            .verify.establichConnectionScreenIsShown()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepB()
            .verify.onboardingABScreen()
    }
}
