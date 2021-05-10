//
//  UpdateFileSelectorImplementationTests.swift
//  ProtonVPN - Created on 2021-01-18.
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

@testable import ProtonVPN

class UpdateFileSelectorImplementationTests: XCTestCase {

    func testDefaultFile() throws {
        let propertyManager = PropertiesManagerMock()
        let factory = UpdateFileSelectorImplementationFactory(propertiesManager: propertyManager)
        let selector = UpdateFileSelectorImplementation(factory)
        
        // test on current system
        var version = "2"
        if #available(OSX 10.15, *) {
            version = "3"
        }
        propertyManager.earlyAccess = false
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-update\(version).xml")

        propertyManager.earlyAccess = true
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-early-access-update\(version).xml")
        
        // Force macos 10.15+ file
        selector.forceNECapableOS = true
        version = "3"
        propertyManager.earlyAccess = false
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-update\(version).xml")
        propertyManager.earlyAccess = true
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-early-access-update\(version).xml")
        
        // Force older file
        selector.forceNECapableOS = false
        version = "2"
        propertyManager.earlyAccess = false
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-update\(version).xml")
        propertyManager.earlyAccess = true
        XCTAssert(selector.updateFileUrl == "https://protonvpn.com/download/macos-early-access-update\(version).xml")
    }

}

fileprivate class UpdateFileSelectorImplementationFactory: PropertiesManagerFactory {
    
    var propertiesManager: PropertiesManagerProtocol
    
    init(propertiesManager: PropertiesManagerProtocol) {
        self.propertiesManager = propertiesManager
    }
    
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
    
}
