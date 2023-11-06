//
//  Created on 27.01.2022.
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

final class OnboardingSampleAppUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.

        app.launchArguments = ["UITests"]
        app.launch()
    }

    private lazy var onboardingMainRobot = OnboardingMainRobot(app: app)

    func testStartOnboardingConnectNowAndGetPlus() {
        onboardingMainRobot
            .startOnboarding()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFourSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFifthSlideIsShown()
            .nextStepA()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepA()
            .verify.accessAllCountriesScreenIsShown()
            .getPlus()
            .plusPlanIsPurchased()
            .verify.onboardingScreen()
    }

    func testStartOnboardingConnectNowGetPlusAndSkipConnecting() {
        onboardingMainRobot
            .startOnboarding()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFourSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFifthSlideIsShown()
            .nextStepA()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepA()
            .verify.accessAllCountriesScreenIsShown()
            .getPlus()
            .plusPlanIsPurchased()
            .verify.onboardingScreen()
    }

    func testStartOnboardingConnectNowFreePlan() {
        onboardingMainRobot
            .startOnboarding()
            .verify.welcomeScreenIsShown()
            .startUserOnboarding()
            .verify.onboardingFirstSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingSecondSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingThirdSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFourSlideIsShown()
            .nextOnboardingScreen()
            .verify.onboardingFifthSlideIsShown()
            .nextStepA()
            .verify.establishConnectionScreenIsShown()
            .connectNow()
            .verify.connectionScreenIsShown()
            .nextStepA()
            .verify.accessAllCountriesScreenIsShown()
            .useFreePlanA()
            .verify.onboardingScreen()
    }
}
