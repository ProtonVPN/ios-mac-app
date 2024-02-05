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

class FreeRescopeTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    
    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testProfileCreationUnavailableForFreeUser() throws {
        let user = User(name: StringUtils().randomAlphanumericString(length: 10), password: "12l3")
        let quarkUser = try quarkCommands.userCreate(user: user)
        try quarkCommands.enableSubscription(id: quarkUser!.decryptedUserId, plan: "vpnplus")

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
