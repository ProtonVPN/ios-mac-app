//
//  UnloggedUserTests.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import XCTest

class UnloggedUserTests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }
    
    func testDiscoverTheApp() {
        let skipButton = app.buttons["Skip"]
        skipButton.tap()
        app.buttons["Discover the app"].tap()
        snapshot("Discover-1")
        
        // Check one the countries servers list
        app.tables.firstMatch.cells.firstMatch.tap() // Click on country
        snapshot("Discover-2")
        app.tables.firstMatch.cells.firstMatch.tap() // Click on server
        
        app.buttons["close"].tap()
        
        app.navigationBars.buttons.firstMatch.tap() // Back button
        
        // Click through tabs
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["Map"].tap()
        snapshot("Discover-Map")
        tabBarsQuery.buttons["Profiles"].tap()
        snapshot("Discover-Profiles")
        tabBarsQuery.buttons["Settings"].tap()
    }
}
