//
//  MigrationVersionTest.swift
//  vpncore - Created on 23/07/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest

class MigrationVersionTest: XCTestCase {
    
    func testCompare() {
        let v1 = MigrationVersion("1.6.0")
        let v2 = MigrationVersion("1.6.1")
        let v3 = MigrationVersion("1.5.0")
        
        XCTAssertEqual(v1 > v2, false)
        XCTAssertEqual(v1 > v1, false)
        XCTAssertEqual(v1 > v3, true)
        XCTAssertEqual(v3 > v2, false)
    }
    
    func testMigration1() {
        var checkValue = 0
        let propertiesManager = PropertiesManager()
        MigrationManager(propertiesManager, currentAppVersion: "1.6.0").addCheck("1.6.1") { _ , completion in
                checkValue = 1
                completion(nil)
        }.migrate { _ in
            XCTAssertEqual(checkValue, 1)
        }
    }
    
    func testMigration2() {
        var checkValue = 0
        let propertiesManager = PropertiesManager()
        MigrationManager(propertiesManager, currentAppVersion: "1.6.0").addCheck("1.5.9") { _ , completion in
            checkValue = 1
            completion(nil)
        }.addCheck("1.6.0") { _ , completion in
            checkValue = 2
            completion(nil)
        }.migrate { _ in
            XCTAssertEqual(checkValue, 0)
        }
    }
    
    func testMigration3() {
        var checkValue = 0
        let propertiesManager = PropertiesManager()
        
        MigrationManager(propertiesManager, currentAppVersion: "1.6.0").addCheck("1.5.9") { _ , completion in
            checkValue = checkValue + 1
            completion(nil)
        }.addCheck("1.6.0") { _ , completion in
            checkValue = checkValue + 1
            completion(nil)
        }.addCheck("1.6.1") { _ , completion in
            checkValue = checkValue + 1
            completion(nil)
        }.addCheck("1.7.1") { _ , completion in
            checkValue = checkValue + 1
            completion(nil)
        }.addCheck("1.8") { _ , completion in
            checkValue = checkValue + 1
            completion(nil)
        }.migrate { _ in
            XCTAssertEqual(checkValue, 3)
        }
    }
}
