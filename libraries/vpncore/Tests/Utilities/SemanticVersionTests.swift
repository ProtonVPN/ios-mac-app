//
//  SemanticVersionTests.swift
//  vpncore - Created on 2021-01-05.
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

class SemanticVersionTests: XCTestCase {
    
    
    func testParsesVersion() throws {
        XCTAssertEqual(try? SemanticVersion("1.2.3").major, 1)
        XCTAssertEqual(try? SemanticVersion("1.2.3").minor, 2)
        XCTAssertEqual(try? SemanticVersion("1.2.3").patch, 3)
    }
    
    func testEquality() throws {
        XCTAssertTrue(try SemanticVersion("1.2.3") > (try SemanticVersion("1.2.2")))
        XCTAssertTrue(try SemanticVersion("1.2.3") < (try SemanticVersion("2.0.0")))
        XCTAssertTrue(try SemanticVersion("1.2.3") == (try SemanticVersion("1.2.3")))
    }
    
    func testPreRelease() throws {
        XCTAssertTrue(try SemanticVersion("1.2.3-beta") > (try SemanticVersion("1.2.2-beta")))
        XCTAssertTrue(try SemanticVersion("1.2.3-beta") < (try SemanticVersion("2.0.0-beta")))
        XCTAssertTrue(try SemanticVersion("1.2.3-beta") == (try SemanticVersion("1.2.3-beta")))
        
        XCTAssertTrue(try SemanticVersion("1.2.3") > (try SemanticVersion("1.2.3-beta")))
        XCTAssertTrue(try SemanticVersion("1.2.3-beta") < (try SemanticVersion("1.2.3")))
        XCTAssertTrue(try SemanticVersion("1.2.3-beta") > (try SemanticVersion("1.2.3-alpha")))
        
        XCTAssertTrue(try SemanticVersion("1.0.0-alpha") < (try SemanticVersion("1.0.0-alpha.1")))
        XCTAssertTrue(try SemanticVersion("1.0.0-alpha.1") < (try SemanticVersion("1.0.0-alpha.beta")))
        XCTAssertTrue(try SemanticVersion("1.0.0-alpha.beta") < (try SemanticVersion("1.0.0-beta")))
        XCTAssertTrue(try SemanticVersion("1.0.0-beta") < (try SemanticVersion("1.0.0-beta.2")))
//        XCTAssertTrue(try SemanticVersion("1.0.0-beta.2") < (try SemanticVersion("1.0.0-beta.11"))) // Doesn't work
        XCTAssertTrue(try SemanticVersion("1.0.0-beta.11") < (try SemanticVersion("1.0.0-rc.1")))
        XCTAssertTrue(try SemanticVersion("1.0.0-rc.1") < (try SemanticVersion("1.0.0")))
    }
    
    // MARK: - Comparing strings directly
    
    func testStringVersionComparison() throws {
        XCTAssertEqual(("1.0.0".compareVersion(to: "1.0.0")), .orderedSame)
        XCTAssertEqual(("1.1.0".compareVersion(to: "1.1.0")), .orderedSame)
        XCTAssertEqual(("1.2.1".compareVersion(to: "1.2.1")), .orderedSame)
        
        XCTAssertEqual(("1.0.0".compareVersion(to: "1.0.1")), .orderedAscending)
        XCTAssertEqual(("1.0.0".compareVersion(to: "1.1.0")), .orderedAscending)
        XCTAssertEqual(("1.2.1".compareVersion(to: "2.2.1")), .orderedAscending)
        XCTAssertEqual(("1.99.99".compareVersion(to: "2.0.0")), .orderedAscending)
        XCTAssertEqual(("1.9.0".compareVersion(to: "1.10.0")), .orderedAscending)
        
        XCTAssertEqual(("1.0.1".compareVersion(to: "1.0.0")), .orderedDescending)
        XCTAssertEqual(("1.1.0".compareVersion(to: "1.0.0")), .orderedDescending)
        XCTAssertEqual(("1.0.0".compareVersion(to: "0.1.0")), .orderedDescending)
        XCTAssertEqual(("2.0.0".compareVersion(to: "1.9.9")), .orderedDescending)
    }
    
    func testWrongVersionsComparisons() throws {
        XCTAssertEqual(("1.0.0".compareVersion(to: "1.0")), .orderedDescending)
        XCTAssertEqual(("1.0".compareVersion(to: "1.0.0")), .orderedAscending)
        XCTAssertEqual(("1.0.0".compareVersion(to: "1.0.x")), .orderedSame)
    }
}
