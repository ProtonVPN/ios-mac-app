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

class NavigationRobot {

    enum NavigationIdentifier: String {
        case settingsTab = "Settings tab"
        case countriesTab = "Countries tab"
        case homeTab = "Home tab"
    }

    lazy var verify = Verify(app: app, robot: self)

    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    func navigate(to identifier: NavigationIdentifier) -> Self {
        app.links[identifier.rawValue].click()
        return self
    }
}

extension NavigationRobot {
    class Verify {
        enum Page {
            case settings
            case home
            case countries
        }

        let app: XCUIApplication
        weak var robot: NavigationRobot?

        init(app: XCUIApplication, robot: NavigationRobot) {
            self.app = app
            self.robot = robot
        }

        @discardableResult
        func isPresented(page: Page) -> NavigationRobot {
            switch page {
            case .settings:
                XCTAssert(app.buttons["Killswitch"].exists)
            case .home:
                XCTAssert(app.staticTexts["You are unprotected"].exists)
            case .countries:
                XCTAssert(app.staticTexts["Countries view, click me"].exists)
            }
            return robot!
        }
    }
}
