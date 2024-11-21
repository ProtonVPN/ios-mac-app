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
import Strings

fileprivate let countrySearchInput = Localizable.searchBarPlaceholder
fileprivate let clearSearchButton = Localizable.searchRecentClear
fileprivate let buttonConnectDisconnect = "ic power off"
fileprivate let clearTextButton = "Clear text"

class CountrySearchRobot: ConnectionBaseRobot {

    let verify = Verify()

    @discardableResult
    func search(for value: String) -> CountrySearchRobot {
        searchField(countrySearchInput).tap()
        searchField(countrySearchInput).typeText(value)
        return self
    }

    @discardableResult
    func hitPowerButton(server: String) -> ConnectionStatusRobot {
        cell().firstMatch()
            .onChild(staticText(server))
            .onChild(button(buttonConnectDisconnect)).tap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }

    @discardableResult
    func clearSearch() -> CountrySearchRobot {
        button(clearTextButton).tap()
        button(Localizable.cancel).tap()
        return self
    }

    class Verify: CoreElements {
        @discardableResult
        func serverFound(server: String) -> CountrySearchRobot {
            cell().firstMatch().onChild(staticText(server)).waitUntilExists(time: 2).checkExists()
            return CountrySearchRobot()
        }
    }
}
