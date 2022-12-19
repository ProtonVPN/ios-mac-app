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
@testable import vpncore

class MigrationVersionTest: XCTestCase {
        
    func testSimpleMigration() {
        var checkValue = 0
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "0.0.0"
        
        MigrationManager(propertiesManager, currentAppVersion: "1.6.0")
            .addCheck("1.6.1") { _, completion in
                checkValue += 1
                completion(nil)
            }.migrate { _ in
                XCTAssertEqual(checkValue, 1)
            }
    }
    
    func testNoMigrationWhenNotNeeded() {
        var checkValue = 0
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "1.6.0"
        
        MigrationManager(propertiesManager, currentAppVersion: "1.6.0")
            .addCheck("1.5.9") { _, completion in
                checkValue += 1
                XCTAssert(false, "This update block should not be run!")
                completion(nil)
            }.addCheck("1.6.0") { _, completion in
                checkValue += 1
                XCTAssert(false, "This update block should not be run!")
                completion(nil)
            }.migrate { _ in
                XCTAssertEqual(checkValue, 0)
            }
    }
    
    func testMigratesOnlyWhatIsNeeded() {
        var checkValue = 0
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "1.6.0"
        
        MigrationManager(propertiesManager, currentAppVersion: "1.8.0")
            .addCheck("1.5.9") { _, completion in
                checkValue += 1
                XCTAssert(false, "This update block should not be run!")
                completion(nil)
            }.addCheck("1.6.0") { _, completion in
                checkValue += 1
                XCTAssert(false, "This update block should not be run!")
                completion(nil)
            }.addCheck("1.6.1") { _, completion in
                checkValue += 1
                completion(nil)
            }.addCheck("1.7.1") { _, completion in
                checkValue += 1
                completion(nil)
            }.addCheck("1.8.0") { _, completion in
                checkValue += 1
                completion(nil)
            }.migrate { _ in
                XCTAssertEqual(checkValue, 3)
            }
    }
    
    func testMigrationSavesCurrentAppVersionToProperties() {
        var checkValue = 0
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "0.0.0"
        
        let current = "2.4.0"
        MigrationManager(propertiesManager, currentAppVersion: current)
            .addCheck("1.6.1") { _, completion in
                checkValue += 1
                completion(nil)
            }.migrate { _ in
                XCTAssertEqual(checkValue, 1)
            }
        
        XCTAssertEqual(current, propertiesManager.lastAppVersion)
    }
    
    func testMigrationSavesMigratedVersionToPropertiesAfterEachStep() {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "0.0.0"
        
        let current = "2.4.0"
        let manager = MigrationManager(propertiesManager, currentAppVersion: current)
        _ = manager.addCheck("1.6.1") { _, completion in
            completion(nil)
        }
        
        _ = manager.addCheck("2.0.0") { _, completion in
            // At this point migration manager had to save last succeeded migration version into properties
            XCTAssertEqual("1.6.1", propertiesManager.lastAppVersion)
            completion(nil)
        }
        
        manager.migrate { _ in
        }
        
        XCTAssertEqual(current, propertiesManager.lastAppVersion)
    }
    
    func testMigrationDoesntSaveVersionToPropertiesAfterError() {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.lastAppVersion = "0.0.0"
        
        let current = "2.4.0"
        let manager = MigrationManager(propertiesManager, currentAppVersion: current)
        _ = manager.addCheck("1.6.1") { _, completion in
            completion(nil)
        }
        
        _ = manager.addCheck("2.0.0") { _, completion in
            // At this point migration manager had to save last succeeded migration version into properties
            XCTAssertEqual("1.6.1", propertiesManager.lastAppVersion)
            completion(JustAnError())
        }
        
        _ = manager.addCheck("2.2.0") { _, completion in
            XCTAssert(false, "This update block should not be run!")
            completion(nil)
        }
        
        manager.migrate { _ in
        }
        
        // Version is not changed because 2.0.0 block failed
        XCTAssertEqual("1.6.1", propertiesManager.lastAppVersion)
    }
    
}

private struct JustAnError: Error {}
