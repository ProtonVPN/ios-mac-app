//
//  Created on 2021-12-21.
//
//  Copyright (c) 2021 Proton AG
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

import pmtest

fileprivate let summaryTitle = "Welcome to Proton VPN"
fileprivate let summaryDescription = "Learn how to get the most out of ProtonVPN in just a few seconds"
fileprivate let takeTourButton = "Take a tour"
fileprivate let skipButton = "Skip"
fileprivate let slideOneTitle = "Be protected everywhere"

class SummarySignupRobot: CoreElements {
    
    public let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func summaryScreenIsShown() -> OnboardingRobot {
            staticText(summaryTitle).wait(time: 120).checkExists()
            staticText(summaryDescription).wait(time: 120).checkExists()
            return OnboardingRobot()
        }
    }
}
