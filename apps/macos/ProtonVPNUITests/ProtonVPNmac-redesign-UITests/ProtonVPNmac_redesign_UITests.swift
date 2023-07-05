//
//  Created on 18/05/2023.
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

final class ProtonVPNmac_redesign_UITests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    func testFirstLevelNavigation() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        let navigationRobot = NavigationRobot(app: app)

        logoutIfNeeded()
        loginAsPlusUser()

        navigationRobot
            .navigate(to: .settingsTab)
            .verify.isPresented(page: .settings)
            .navigate(to: .countriesTab)
            .verify.isPresented(page: .countries)
            .navigate(to: .homeTab)
            .verify.isPresented(page: .home)
    }
}
