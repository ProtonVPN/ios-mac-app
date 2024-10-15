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
import fusion
import UITestsHelpers

fileprivate let showMapButton = "Show map"
fileprivate let hideMapButton = "Hide map"
fileprivate let statusDisconnected = "ConnectionStatus"
fileprivate let connectImage = "ConnectImage"

class MapRobot: CoreElements {
    
    func clickShowMap() -> MapRobot {
        if button(hideMapButton).waitUntilExists(time: 1).hittable() {
            return self
        }
        button(showMapButton).tap()
        return self
    }
    
    func clickHideMap() -> MapRobot {
        button(hideMapButton).forceTap()
        return self
    }
    
    let verify = Verify()
    
    class Verify: CoreElements {

        @discardableResult
        func checkMapIsOpen() -> MapRobot {
            button(hideMapButton).waitUntilExists(time: WaitTimeout.short).checkExists()
            staticText(statusDisconnected).waitUntilExists(time: WaitTimeout.short).checkExists()
            image(connectImage).checkExists()
            return MapRobot()
        }
        
        @discardableResult
        func checkMapIsHidden() -> MapRobot {
            button(showMapButton).waitUntilExists(time: WaitTimeout.short).checkExists()
            staticText(statusDisconnected).checkDoesNotExist()
            image(connectImage).checkDoesNotExist()
            return MapRobot()
        }
    }
}
