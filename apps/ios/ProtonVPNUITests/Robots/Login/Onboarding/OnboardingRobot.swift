//
//  Created on 2022-01-20.
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

import fusion

fileprivate let establishConnectionTitle = "Establish your first connection"
fileprivate let continueButton = "Continue"
fileprivate let skipButton = "SkipButton"
fileprivate let nextButton = "Next"
fileprivate let closeButton = "CloseButton"
fileprivate let takeTourButton = "TakeATourButton"
fileprivate let upgradeButton = "Upgrade"

class OnboardingRobot: CoreElements {
    
    @discardableResult
    func startUserOnboarding() -> OnboardingRobot {
        button(takeTourButton).tap()
        return OnboardingRobot()
    }
    
    @discardableResult
    func skipOnboardingStep() -> OnboardingRobot {
        button(skipButton).tap()
        return OnboardingRobot()
    }
    
    @discardableResult
    func nextOnboardingStep() -> OnboardingRobot {
        button(nextButton).tap()
        return OnboardingRobot()
    }
    
    @discardableResult
    func continueOnboardingStep() -> OnboardingRobot {
        button(continueButton).tap()
        return OnboardingRobot()
    }
    
    @discardableResult
    func closeOnboardingScreen() -> OnboardingRobot {
        button(closeButton).tap()
        return OnboardingRobot()
    }
    
    @discardableResult
    func startUpgrade() -> SubscriptionsRobot {
        button(upgradeButton).tap()
        return SubscriptionsRobot()
    }
    
    @discardableResult
    func skipFullOnboarding() -> OnboardingRobot {
        skipOnboardingStep()
        nextOnboardingStep()
        nextOnboardingStep()
        skipOnboardingStep()
        continueOnboardingStep() //toliau tesiais upgrade arba skip
        closeOnboardingScreen()
        return OnboardingRobot()
    }
    
    func skipOnboarding() -> OnboardingRobot {
        skipOnboardingStep()
        nextOnboardingStep()
        nextOnboardingStep()
        skipOnboardingStep()
        continueOnboardingStep()
        return OnboardingRobot()
    }
    
}
    
    
    
//
//
//    func startUsingProtonVpn() -> OnboardingRobot {
//        button(continueButton).tap()
//        return OnboardingRobot()
//    }
//
//    func closeOnboardingScreen() -> OnboardingRobot {
//        button(closeButton).tap()
//        return OnboardingRobot()
//    }
//
//    func closeScreen() -> MainRobot {
//        button(closeButton).tap()
//        return MainRobot()
//    }
//
//    func startUserOnboarding() -> OnboardingRobot {
//          button(takeTourButton).tap()
//          return OnboardingRobot()
//    }
//
//    func skipOnboarding() -> OnboardingRobot {
//          button(skipButton).tap()
//          return OnboardingRobot()
//    }
//
//    func nextOnboardingStep() -> OnboardingRobot {
//          button(nextButton).tap()
//          return OnboardingRobot()
//    }
//
//    func startUpgrade() -> SubscriptionsRobot {
//          button(upgradeButton).tap()
//          return SubscriptionsRobot()
//    }
//}
