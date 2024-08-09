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
fileprivate let serverListTableId = "ServerListTable"

class CountriesSectionRobot {
    
    func searchForServer(serverName: String) -> CountriesSectionRobot {
        app.textFields[searchTextField].click()
        app.textFields[searchTextField].typeText(serverName)
        return CountriesSectionRobot()
    }
    
    func clearSearch() -> CountriesSectionRobot {
        app.buttons[clearSearchButton].click()
        return CountriesSectionRobot()
    }
    
    func expandCountry(country: String) -> CountriesSectionRobot {
        // getting country cell
        let cell = app.cells[country]
        // expanding country by clicking on country row
        cell.forceClick()
        return CountriesSectionRobot()
    }
    
    func connectToServer(server: String) -> CountriesSectionRobot {
        let serverCell = app.tables[serverListTableId].cells.containing(NSPredicate(format: "label CONTAINS[c] %@", server)).firstMatch
        if serverCell.waitForExistence(timeout: 1) {
            // hovering over the cell with country in order to make "Connect" button visible
            // using dx: 0.7 as Connect button placed at the right part of the cell
            serverCell.forceHover(dx: 0.7, dy: 0.5)
            
            let connectButton = serverCell.buttons["Connect"].firstMatch
            if connectButton.exists {
                connectButton.click()
            } else {
                // Clicking cell with country by coordinates hoping that Connect button is there
                // using dx: 0.7 as Connect button placed at the right part of the cell
                serverCell.forceClick(dx: 0.7, dy: 0.5)
            }
        } else {
            XCTFail("Server '\(server)' was not found")
        }
        return CountriesSectionRobot()
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkCountryExists(_ name: String) -> CountriesSectionRobot {
            XCTAssertTrue(app.tables[serverListTableId].cells[name].exists)
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkCountryFound(country: String) -> CountriesSectionRobot {
            let serverListTable = app.tables[serverListTableId]
            XCTAssertTrue(serverListTable.waitForExistence(timeout: 2), "Countries list table does not appear")
            XCTAssertEqual(serverListTable.tableRows.count, 2, "Country \(country) was not found")
            
            let countryCell = serverListTable.cells[country]
            XCTAssertTrue(countryCell.exists, "\(country) cell is not visible at the countries list table")
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkServerExist(server: String) -> CountriesSectionRobot {
            let serverListTable = app.tables[serverListTableId]
            let predicate = NSPredicate(format: "label CONTAINS[c] '\(server)'")
            XCTAssertTrue(serverListTable.cells.matching(predicate).firstMatch.exists)
            return CountriesSectionRobot()
        }
    }
}
