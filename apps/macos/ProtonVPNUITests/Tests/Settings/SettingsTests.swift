//
//  Created on 2022-01-12.
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

class SettingsTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let settingsRobot = SettingsRobot()
    
    override func setUp() {
         super.setUp()
         logInIfNeeded()
     }
    
    func testNavigateThrouthSettings() {
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .generalTabClick()
            .verify.checkGeneralTabIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .accountTabClick()
            .verify.checkAccountTabIsOpen()
            .closeSettings()
            .verify.checkSettingsModalIsClosed()
    }
    
    // Map
    func testOpenAndHideMap() {
        settingsRobot
            .showMapClick()
            .verify.checkMapIsOpen()
            .hideMapClick()
            .verify.checkMapIsHidden()
    }
}
