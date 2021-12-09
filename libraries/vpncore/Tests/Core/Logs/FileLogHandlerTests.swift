//
//  Created on 2021-11-23.
//
//  Copyright (c) 2021 Proton AG
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
@testable import vpncore

class FileLogHandlerTests: XCTestCase {
    
    private let manager = FileManager.default
    private var folder: URL!
    private var file: URL!
    
    override func setUpWithError() throws {
        folder = manager.temporaryDirectory.appendingPathComponent("log-tests", isDirectory: true)
        file = folder.appendingPathComponent("ProtonVPNtest.log", isDirectory: false)
        try? manager.removeItem(at: folder)
    }

    override func tearDownWithError() throws {
        try manager.removeItem(at: folder)
    }

    func testCreatesFile() {
        let handler = FileLogHandler(file)
        handler.log(level: .info, message: "Message", metadata: nil, source: "", file: "", function: "", line: 1)
                
        let expectation = XCTestExpectation(description: "File created")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1) {
            if self.manager.fileExists(atPath: self.folder.path), self.manager.fileExists(atPath: self.file.path) {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }
    
    func testRotatesFiles() {
        let handler = FileLogHandler(file)
        handler.maxFileSize = 70
        handler.maxArchivedFilesCount = 50
        
        for i in 1 ... 7 {
            handler.log(level: .info, message: "Message \(i)", metadata: nil, source: "", file: "", function: "", line: 1)
        }
        
        let expectation = XCTestExpectation(description: "3 Files are created")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1) {
            if let files = try? self.manager.contentsOfDirectory(at: self.folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), files.count == 3 {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }
    
    func testDeletesOldFiles() {
        let handler = FileLogHandler(file)
        handler.maxFileSize = 70
        handler.maxArchivedFilesCount = 1
        
        for i in 1 ... 7 {
            handler.log(level: .info, message: "Message \(i)", metadata: nil, source: "", file: "", function: "", line: 1)
        }
        
        let expectation = XCTestExpectation(description: "2 Files are created")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1) {
            if let files = try? self.manager.contentsOfDirectory(at: self.folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), files.count == 2 { // maxArchivedFilesCount + current logfile
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

}
