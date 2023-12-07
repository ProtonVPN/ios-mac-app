//
//  Created on 2023-09-25.
//
//  Copyright (c) 2023 Proton AG
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
import fusion
import ProtonCoreTestingToolkitUITestsLogin
import ProtonCoreQuarkCommands
import ProtonCoreEnvironment

class FreeRescopeTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    private let profileRobot = ProfileRobot()
    private let createProfileRobot = CreateProfileRobot()
    lazy var quarkCommands = QuarkCommands(doh: environment.doh)
    
    lazy var environment: Environment = {
        guard let host = dynamicHost else {
            return .black
        }

        return .custom(host)
    }()
    
    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testProfileCreationUnavailableForFreeUser() throws {
        
        let user = Credentials(username: StringUtils().randomAlphanumericString(length: 10), password: "12l3", plan: "vpnplus")
        quarkCommands.createUser(username: user.username, password: user.password, protonPlanName: user.plan)
        
        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .verify.isShowingUpsellModal(ofType: .profiles)
    }
}
