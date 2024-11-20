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
import Strings
import Foundation

fileprivate let upgradeButton = Localizable.upgrade
fileprivate let getStartedButton = Localizable.modalsCommonGetStarted
fileprivate let closeButton = Localizable.close
fileprivate let continueButton = Localizable.continue
fileprivate let welcomeTitle = Localizable.welcomeToProtonTitle
fileprivate let welcomeSubtitle = Localizable.welcomeToProtonSubtitle
fileprivate let welcomeRedesignedImageId = "welcomeRedesigned"
fileprivate let getStartedImageId = "getStarted"
fileprivate let welcomeBannerTitle = Localizable.welcomeToProtonBannerTitle
fileprivate let settingsTitleCensorship = Localizable.settingsTitleCensorship

class OnboardingRobot: CoreElements {
    
    @discardableResult
    func tapGetStarted() -> SubscriptionModalRobot {
        button(getStartedButton).tap()
        return SubscriptionModalRobot()
    }
    
    @discardableResult
    func tapContinueButton() -> OnboardingRobot {
        button(continueButton).tap()
        return self
    }
    
    @discardableResult
    func skipUpgrade() -> OnboardingRobot {
        button(closeButton).tap()
        return self
    }
    
    @discardableResult
    func tapUpgradePlan() -> SubscriptionModalRobot {
        button(upgradeButton).tap()
        return SubscriptionModalRobot()
    }
    
    @discardableResult
    func startUsingApp() -> HomeRobot {
        button(upgradeButton).tap()
        skipUpgrade()
        return HomeRobot()
    }
    
    public let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func onboardingScreenStep1IsShown(time: TimeInterval = 120) -> OnboardingRobot {
            staticText(welcomeTitle).waitUntilExists(time: time).checkExists()
            staticText(welcomeSubtitle).checkExists()
            image(welcomeRedesignedImageId).checkExists()
            button(continueButton).checkExists()
            return OnboardingRobot()
        }

        @discardableResult
        func onboardingScreenStep2IsShown(time: TimeInterval = 120) -> OnboardingRobot {
            staticText(settingsTitleCensorship).waitUntilExists(time: time).checkExists()
            staticText(Localizable.onboardingUsageStatsTitle).checkExists()
            staticText(Localizable.onboardingCrashReportsDescription).checkExists()
            button(getStartedButton).checkExists()
            return OnboardingRobot()
        }
    }
}
