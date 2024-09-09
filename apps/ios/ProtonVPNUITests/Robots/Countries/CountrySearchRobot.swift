//
//  Created on 4/9/24.
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

import Foundation
import fusion

fileprivate let countrySearchInput = "Country, City or Server"
fileprivate let clearSearchButton = "Clear"
fileprivate let buttonConnectDisconnect = "ic power off"
fileprivate let clearTextButton = "Clear text"

class CountrySearchRobot: CoreElements {
    
    let verify = Verify()
    
    func search(for value: String) -> CountrySearchRobot {
        searchField(countrySearchInput).tap()
        searchField(countrySearchInput).typeText(value)
        return self
    }
    
    func hitPowerButton(server: String) -> CountrySearchRobot {
        cell().firstMatch()
            .onChild(staticText(server))
            .onChild(button(buttonConnectDisconnect)).tap()
        return self
    }
    
    func clearSearch() -> CountrySearchRobot {
        button(clearTextButton).tap()
        button("Cancel").tap()
        return self
    }
    
    class Verify: CoreElements {
        func serverFound(server: String) -> CountrySearchRobot {
            cell().firstMatch().onChild(staticText(server)).waitUntilExists(time: 2).checkExists()
            return CountrySearchRobot()
        }
    }
}
