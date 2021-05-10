//
//  ServerManagerTests.swift
//  ProtonVPN - Created on 27.06.19.
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

import vpncore
import XCTest

class ServerManagerTests: XCTestCase {

    let serverStorage = ServerStorageMock(fileName: "ServerManagerTestServers", bundle: Bundle(for: ServerManagerTests.self))
    
    func testFormGrouping() {
        let freeTierServerManager = ServerManagerImplementation.instance(forTier: 0, serverStorage: serverStorage)
        let grouping = freeTierServerManager.formGrouping(from: serverStorage.fetch())
        
        XCTAssert(grouping.count == 3)
        XCTAssert(grouping[0].0.countryCode == "CA")
        XCTAssert(grouping[0].0.lowestTier == 0)
        XCTAssert(grouping[1].0.countryCode == "HK")
        XCTAssert(grouping[1].0.lowestTier == 2)
        XCTAssert(grouping[2].0.countryCode == "JP")
        XCTAssert(grouping[2].0.lowestTier == 0)
    }
    
    func testStandardGrouping() { 
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .standard)

        XCTAssert(grouping.count == 3)
        XCTAssert(grouping[0].0.countryCode == "CA")
        XCTAssert(grouping[0].1.count == 1)
        XCTAssert(grouping[0].1[0].entryCountryCode == "CA")
        XCTAssert(grouping[0].1[0].exitCountryCode == "CA")

        XCTAssert(grouping[1].0.countryCode == "HK")
        XCTAssert(grouping[2].0.countryCode == "JP")
    }
    
    func testSecureCoreBasicGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 1, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .secureCore)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testSecureCorePlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .secureCore)

        XCTAssert(grouping.count == 1)
        XCTAssert(grouping[0].0.countryCode == "CA")
        XCTAssert(grouping[0].1.count == 1)
        XCTAssert(grouping[0].1[0].entryCountryCode == "CH")
        XCTAssert(grouping[0].1[0].exitCountryCode == "CA")
    }
    
    func testP2pFreeGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 0, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .p2p)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testP2pBasicGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 1, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .p2p)
        
        XCTAssert(grouping.count == 1)
        XCTAssert(grouping[0].0.countryCode == "JP")
        XCTAssert(grouping[0].1.count == 1)
        XCTAssert(grouping[0].1[0].name == "JP#6")
    }
    
    func testP2pPlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .p2p)

        XCTAssert(grouping.count == 1)
        XCTAssert(grouping[0].0.countryCode == "JP")
        XCTAssert(grouping[0].1.count == 2)
        XCTAssert(grouping[0].1[0].name == "JP#6")
        XCTAssert(grouping[0].1[1].name == "JP#7")
    }
    
    func testTorBasicGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 1, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .tor)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testTorPlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .tor)

        XCTAssert(grouping.count == 1)
        XCTAssert(grouping[0].0.countryCode == "JP")
        XCTAssert(grouping[0].1.count == 1)
        XCTAssert(grouping[0].1[0].name == "JP#8")
    }
}
