//
//  URLArrayTests.swift
//  vpncore - Created on 2019-12-11.
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
import vpncore

class URLArrayTests: XCTestCase {

    func testReturnsOnlyReachableFiles() {
        
        // Existing files
        let bundle = Bundle(for: type(of: self))
        let testFile1 = bundle.url(forResource: "test_log_1", withExtension: "log")!
        let testFile2 = bundle.url(forResource: "test_log_2", withExtension: "log")!
        
        // File that doesn't exist
        let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs", isDirectory: true)
        let testFile3 = logsDirectory.appendingPathComponent("test.log", isDirectory: false)
        
        let allFiles = [testFile1, testFile2, testFile3]
        XCTAssert(allFiles.count == 3)
        XCTAssert(allFiles.reachable().count == 2)
    }

}
