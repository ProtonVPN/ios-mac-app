//
//  Created on 2022-02-17.
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

import XCTest

fileprivate let searchTextField = "SearchTextField"
fileprivate let clearSearchButton = "ClearSearchButton"

class SearchRobot {
    
    func typeCountry(_ name: String) -> SearchRobot {
        app.textFields[searchTextField].click()
        app.textFields[searchTextField].typeText(name)
        return SearchRobot()
    }
    
    func clearSearch() -> SearchRobot {
        app.buttons[clearSearchButton].click()
        return SearchRobot()
    }
    
    let verify = Verify()

    class Verify {
        
        @discardableResult
        func checkCountryExists(_ name: String) -> SearchRobot {
            XCTAssertTrue(app.tableRows.cells[name].exists)
            return SearchRobot()
        }
        
        @discardableResult
        func checkAnotherCountryExists(_ name: String) -> SearchRobot {
            XCTAssertTrue(app.tableRows.cells[name].exists)
            return SearchRobot()
        }
    }
}
