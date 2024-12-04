//
//  Created on 4/12/24.
//
//  Copyright (c) 2024 Proton AG
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
import XCTest
import Strings
import UITestsHelpers

fileprivate let connectionDetailsTitle = Localizable.connectionDetailsTitle
fileprivate let connectionFlagInfoId = "connection_flag_info_view"

class ConnectionDetailsRobot: CoreElements {

    let verify = Verify()

    @discardableResult
    public func closeConnectionDetails() -> HomeRobot {
        button("ic-cross").tap()
        return HomeRobot()
    }

    class Verify: CoreElements {

        @discardableResult
        func connectionDetailsIsShown() -> ConnectionDetailsRobot {
            staticText(connectionDetailsTitle).checkExists(message: "Connection details are not shown")
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsHeader(title: String) -> ConnectionDetailsRobot {
            staticText("connection_screen_info")
                .firstMatch()
                .checkContainsLabel(title)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsCountry(name: String) -> ConnectionDetailsRobot {
            staticText("connection_details_country")
                .firstMatch()
                .checkContainsLabel(name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsCity(name: String) -> ConnectionDetailsRobot {
            staticText("connection_details_city")
                .firstMatch()
                .checkContainsLabel(name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsServer(name: String) -> ConnectionDetailsRobot {
            staticText("connection_details_server")
                .firstMatch()
                .checkContainsLabel(name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsProtocol(name: String) -> ConnectionDetailsRobot {
            staticText("connection_details_protocol")
                .firstMatch()
                .checkContainsLabel(name)
            return ConnectionDetailsRobot()
        }
    }
}
