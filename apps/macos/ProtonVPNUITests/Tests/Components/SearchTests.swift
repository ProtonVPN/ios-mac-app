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
import Modals

class SearchTests: ProtonVPNUITests {
    
    private let countriesSelectionRobot = CountriesSectionRobot()
    private let countryToSearchFor = "Japan"
    private let comparisonCountryName = "Netherlands"
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }
    
    func testSearchCountry() {
        loginAsPlusUser()
        
        countriesSelectionRobot
            .searchForServer(serverName: countryToSearchFor)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .verify.checkServerListContain(label: countryToSearchFor)
            .clearSearch()
            .verify.checkCountryExists(comparisonCountryName)
    }
    
    func testSearchFreeUser() {
        loginAsFreeUser()
        
        countriesSelectionRobot
            .verify.checkUpgradeBannerVisible()
            .clickUpgradeBanner()
            .verify.checkModalAppear(type: ModalType.allCountries(numberOfServers: 1, numberOfCountries: 1))
            .closeModal()
        
        countriesSelectionRobot
            .searchForServer(serverName: countryToSearchFor)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .verify.checkServerListContain(label: countryToSearchFor)
            .verify.checkServerListContain(label: "Update required")
            .clearSearch()
            .verify.checkServerListContain(label: comparisonCountryName)
    }
}
