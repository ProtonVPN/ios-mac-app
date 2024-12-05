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
            checkStaticText("connection_screen_info", contains: title)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsCountry(name: String) -> ConnectionDetailsRobot {
            checkStaticText("connection_details_country", contains: name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsCity(name: String) -> ConnectionDetailsRobot {
            checkStaticText("connection_details_city", contains: name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsServer(name: String) -> ConnectionDetailsRobot {
            checkStaticText("connection_details_server", contains: name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        func connectionDetailsProtocol(name: String) -> ConnectionDetailsRobot {
            checkStaticText("connection_details_protocol", contains: name)
            return ConnectionDetailsRobot()
        }

        @discardableResult
        private func checkStaticText(_ identifier: String, contains label: String) -> UIElement {
            return staticText(identifier)
                .firstMatch()
                .checkContainsLabel(label)
        }
    }
}
