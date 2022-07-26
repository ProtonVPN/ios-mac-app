//
//  ExtensionInfoComparisonTests.swift
//  ProtonVPNmacOSTests
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest
import vpncore

class ExtensionInfoComparisonTests: XCTestCase {

    func testEquality() throws {
        XCTAssertEqual(ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"), ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
    }

    func testDifferent() throws {
        XCTAssertTrue(ExtensionInfo(version: "2.1.1", build: "1", bundleId: "id") > ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
        XCTAssertTrue(ExtensionInfo(version: "1.1.1", build: "125", bundleId: "id") > ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
    }
    
}
