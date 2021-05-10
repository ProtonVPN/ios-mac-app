//
//  ServerUtilityTests.swift
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
import vpncore

class ServerUtilityTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCountryIndex() {
        let serverModelUS = self.serverModel("US1", withCountryCode: "US")
        let serverModelGB = self.serverModel("GB1", withCountryCode: "GB")
        
        let groupUS: CountryGroup = (self.countryModel(serverModelUS), [serverModelUS])
        let groupGB: CountryGroup = (self.countryModel(serverModelGB), [serverModelGB])
        
        XCTAssertNotNil(ServerUtility.countryIndex(in: [groupUS, groupGB], countryCode: "US"), "Existing country not found")
        XCTAssertNotNil(ServerUtility.countryIndex(in: [groupUS, groupGB], countryCode: "GB"), "Existing country not found")
        XCTAssertNil(ServerUtility.countryIndex(in: [groupUS, groupGB], countryCode: "PL"), "Non-Existing country")
    }

    func testServerIndex() {
        let serverModelUS1 = self.serverModel("US1", withCountryCode: "US")
        let serverModelUS2 = self.serverModel("US2", withCountryCode: "US")
        let serverModelUS3 = self.serverModel("US3", withCountryCode: "US")
        let serverModelGB = self.serverModel("GB1", withCountryCode: "GB")
        
        let groupUS: CountryGroup = (self.countryModel(serverModelUS1), [serverModelUS1, serverModelUS2])
        let groupGB: CountryGroup = (self.countryModel(serverModelGB), [serverModelGB])
        
        XCTAssertNotNil(ServerUtility.serverIndex(in: [groupUS, groupGB], model: serverModelUS2), "Existing server was not found")
        XCTAssertNotNil(ServerUtility.serverIndex(in: [groupUS, groupGB], model: serverModelGB), "Existing server was not found")
        XCTAssertNil(ServerUtility.serverIndex(in: [groupUS, groupGB], model: serverModelUS3), "Non-Existing server was found")
        
    }
    
    // MARK: Mocks
    
    private func countryModel(_ server: ServerModel) -> CountryModel {
        return CountryModel(serverModel: server)
    }
    
    private func serverModel(_ name: String, withCountryCode code: String) -> ServerModel{
        return ServerModel(
            id: "",
            name: name,
            domain: "1",
            load: 1,
            entryCountryCode: "LT",
            exitCountryCode: code,
            tier: 1,
            feature: ServerFeature.zero,
            city: nil,
            ips: [],
            score: 11,
            status: 1,
            location: ServerLocation(lat: 1, long: 2)
        )
    }
    
}
