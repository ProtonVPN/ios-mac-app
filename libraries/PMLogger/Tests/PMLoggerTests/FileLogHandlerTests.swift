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
@testable import PMLogger

class FileLogHandlerTests: XCTestCase {

    private var folder: URL = URL(string: "/tmp")!
    private var file: URL!
    
    override func setUpWithError() throws {
        file = folder.appendingPathComponent("ProtonVPNtest.log", isDirectory: false)
    }

    func testCreatesFile() {
        let expectationDelegate = XCTestExpectation(description: "Delegate called after file created")
        let expectationCreateFile = XCTestExpectation(description: "File creation requested from OS")

        let fileManager = FileManagerMock()
        fileManager.createFileStub.addToBody { _, _, _, _ in
            expectationCreateFile.fulfill()
            return true
        }

        let delegate = LogDelegate()
        delegate.newFileCallback = {
            expectationDelegate.fulfill()
        }

        let handler = FileLogHandler(file, fileManager: fileManager)
        handler.delegate = delegate
        handler.log(level: .info, message: "Message", metadata: nil, source: "", file: "", function: "", line: 1)

        wait(for: [expectationDelegate, expectationCreateFile], timeout: 3)
    }
    
    func testRotatesFiles() {
        let expectationRotation = XCTestExpectation(description: "Files are rotated 2 times")
        expectationRotation.expectedFulfillmentCount = 2
        expectationRotation.assertForOverFulfill = true

        let expectationMoveFileCount = XCTestExpectation(description: "Files were moved/copied 2 times")
        expectationMoveFileCount.expectedFulfillmentCount = 2
        expectationMoveFileCount.assertForOverFulfill = true

        let expectationNewFileCount = XCTestExpectation(description: "3 new files created")
        expectationNewFileCount.expectedFulfillmentCount = 3
        expectationNewFileCount.assertForOverFulfill = true

        let fileSystem = FileSystemMock()
        fileSystem.createFileCallback = { expectationNewFileCount.fulfill() }
        fileSystem.moveFileCallback = { expectationMoveFileCount.fulfill() }

        let handler = FileLogHandler(file, fileManager: fileSystem.fileManager)
        handler.maxFileSize = 70
        handler.maxArchivedFilesCount = 50
        
        let delegate = LogDelegate()
        delegate.rotationCallback = {
            expectationRotation.fulfill()
        }
        handler.delegate = delegate
        
        for i in 1 ... 7 {
            handler.log(level: .info, message: "Message \(i)", metadata: nil, source: "", file: "", function: "", line: 1)
        }
        
        wait(for: [expectationRotation, expectationNewFileCount, expectationMoveFileCount], timeout: 3)
    }
    
    func testDeletesOldFiles() {
        let expectationFileCount = XCTestExpectation(description: "Max 2 files are present an the same time")

        let expectationRotation = XCTestExpectation(description: "Files are rotated 3 times")
        expectationRotation.expectedFulfillmentCount = 3
        expectationRotation.assertForOverFulfill = true

        let expectationDeletion = XCTestExpectation(description: "2 files are deleted")
        expectationDeletion.expectedFulfillmentCount = 2
        expectationDeletion.assertForOverFulfill = true

        let fileSystem = FileSystemMock()
        fileSystem.removeFileCallback = { expectationDeletion.fulfill() }
        
        let handler = FileLogHandler(file, fileManager: fileSystem.fileManager)
        handler.maxFileSize = 70
        handler.maxArchivedFilesCount = 1
        
        let delegate = LogDelegate()
        delegate.newFileCallback = {
            guard let files = try? fileSystem.fileManager.contentsOfDirectory(at: self.folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
                return
            }
            if files.count == 2 { // maxArchivedFilesCount + current logfile
                expectationFileCount.fulfill()
            } else if files.count > 2 {
                XCTFail("More than 2 files present")
            }
        }
        delegate.rotationCallback = {
            expectationRotation.fulfill()
        }
        handler.delegate = delegate
        
        for i in 1 ... 9 {
            handler.log(level: .info, message: "Message \(i)", metadata: nil, source: "", file: "", function: "", line: 1)
        }
        
        wait(for: [expectationFileCount, expectationRotation, expectationDeletion], timeout: 3)
    }

}

private class LogDelegate: FileLogHandlerDelegate {
    
    var newFileCallback: (() -> Void)?
    var rotationCallback: (() -> Void)?
    
    func didCreateNewLogFile() {
        newFileCallback?()
    }
    
    func didRotateLogFile() {
        rotationCallback?()
    }
    
}
