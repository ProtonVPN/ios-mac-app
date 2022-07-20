//
//  Created on 2022-03-01.
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

import Foundation
import XCTest

fileprivate let showMapButton = "Show map"
fileprivate let hideMapButton = "Hide map"
fileprivate let statusDisconnected = "ConnectionStatus"
fileprivate let connectImage = "ConnectImage"

class MapRobot {
    
    func showMapClick() -> MapRobot {
        XCTAssertTrue(app.buttons[showMapButton].waitForExistence(timeout: 5))
        app.buttons[showMapButton].click()
        return self
    }
    
    func hideMapClick() ->  MapRobot {
        app.buttons[hideMapButton].click()
        return self
    }
    
    let verify = Verify()
    
    class Verify {

        @discardableResult
        func checkMapIsOpen() -> MapRobot {
            XCTAssertTrue(app.buttons[hideMapButton].exists)
            XCTAssertTrue(app.staticTexts[statusDisconnected].waitForExistence(timeout: 2))
            XCTAssertTrue(app.images[connectImage].exists)
            return MapRobot()
        }
        
        @discardableResult
        func checkMapIsHidden() -> MapRobot {
            XCTAssertTrue(app.buttons[showMapButton].waitForExistence(timeout: 2))
            XCTAssertFalse(app.staticTexts[statusDisconnected].waitForExistence(timeout: 2))
            XCTAssertFalse(app.images[connectImage].exists)
            return MapRobot()
        }
    }
}
