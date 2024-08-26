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
import Strings

fileprivate let searchTextField = "SearchTextField"
fileprivate let clearSearchButton = "ClearSearchButton"
fileprivate let serverListTableId = "ServerListTable"

class CountriesSectionRobot {
    
    func searchForServer(serverName: String) -> CountriesSectionRobot {
        app.textFields[searchTextField].click()
        app.textFields[searchTextField].typeText(serverName)
        return self
    }
    
    func clearSearch() -> CountriesSectionRobot {
        app.buttons[clearSearchButton].click()
        return self
    }
    
    func expandCountry(country: String) -> CountriesSectionRobot {
        // getting country cell
        let cell = app.cells[country]
        // expanding country by clicking on country row
        cell.forceClick()
        return self
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
        return self
    }
    
    func clickUpgradeBanner() -> ModalsRobot {
        app.tables[serverListTableId].cells[Localizable.freeConnectionsModalBanner].forceClick()
        return ModalsRobot()
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkCountryExists(_ name: String) -> CountriesSectionRobot {
            XCTAssertTrue(app.tables[serverListTableId].cells[name].exists, "'\(name)' country does not exist at the servers list table")
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkAmountOfLocationsFound(expectedAmount: Int) -> CountriesSectionRobot {
            let serverListTable = app.tables[serverListTableId]
            let predicate = NSPredicate(format: "value CONTAINS[c] %@ OR value CONTAINS[c] %@", "All locations", "Plus locations")
            
            let locationsCounterCells = serverListTable.staticTexts.matching(predicate).firstMatch
            
            let value = locationsCounterCells.value as? String ?? ""
            let serversFound: Int = extractServerCount(from: value)
            
            XCTAssertEqual(serversFound, expectedAmount, "Invalid amount of servers found. Expected: \(expectedAmount), Actual: \(serversFound)")
            
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkServerListContain(label: String) -> CountriesSectionRobot {
            let serverListTable = app.tables[serverListTableId]
            let predicate = NSPredicate(format: "label CONTAINS[c] '\(label)'")
            XCTAssertTrue(serverListTable.cells.matching(predicate).firstMatch.exists)
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkUpgradeBannerVisible() -> CountriesSectionRobot {
            let banner = app.tables[serverListTableId].cells[Localizable.freeConnectionsModalBanner]
            XCTAssertTrue(banner.waitForExistence(timeout: WaitTimeout.short), "freeConnectionsModalBanner is not visible")
            return CountriesSectionRobot()
        }
        
        @discardableResult
        func checkWrongCountryBannerVisible() -> CountriesSectionRobot {
            let banner = app.tables[serverListTableId].cells[Localizable.wrongCountryBannerText]
            XCTAssertTrue(banner.waitForExistence(timeout: WaitTimeout.short), "wrongCountryBannerText is not visible")
            return CountriesSectionRobot()
        }
        
        // MARK: Private functions
        
        /// Extracts the amount of servers from a string formatted as "All locations (X)"
        /// where X is the number of servers inside the brackets.
        /// - Parameter string: The string from which the server count will be extracted.
        /// - Returns: The number of servers as an `Int` if the extraction is successful, otherwise `0`.
        private func extractServerCount(from string: String) -> Int {
            // Use a regular expression to match the pattern with a number inside brackets
            let pattern = "\\((\\d+)\\)"
            
            // Attempt to create a regular expression object
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return 0
            }
            
            // Search for matches in the string
            let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            
            // Extract the first match, which is the number in brackets
            if let match = matches.first, let range = Range(match.range(at: 1), in: string) {
                // Convert the substring to an Int and return it
                return Int(string[range]) ?? 0
            }
            
            // Return 0 if no match was found
            return 0
        }
    }
}
