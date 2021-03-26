//
//  PMLogtests.swift
//  vpncore - Created on 2021-03-26.
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

class PMLogtests: XCTestCase {

    func testDumpWritesAndOverwritesFileContents() throws {
        
        let filename = "testLog.txt"
        let log = "Very interesting and useful log entry"
        let log2 = "Not su useful log that should overwrite previous"

        let logUrl = PMLog.logFile(filename)!
        if FileManager.default.fileExists(atPath: logUrl.path) {
            try FileManager.default.removeItem(at: logUrl)
        }
        
        PMLog.dump(logs: log, toFile: filename)
        let fileContent = String(data: FileManager.default.contents(atPath: logUrl.path)!, encoding: .utf8)
        XCTAssertEqual(log, fileContent)
        
        PMLog.dump(logs: log2, toFile: filename)
        let fileContent2 = String(data: FileManager.default.contents(atPath: logUrl.path)!, encoding: .utf8)
        XCTAssertEqual(log2, fileContent2)
        
        try FileManager.default.removeItem(at: logUrl)
    }

}
