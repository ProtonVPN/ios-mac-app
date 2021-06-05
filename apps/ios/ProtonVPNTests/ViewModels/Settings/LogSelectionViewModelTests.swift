//
//  LogSelectionViewModelTests.swift
//  ProtonVPNTests
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest

class LogSelectionViewModelTests: XCTestCase {

    var viewModel: LogSelectionViewModel!
    var provider: MockLogFilesProvider!
    let fileManager = FileManager()
    var file1: URL!
    var file2: URL!
    var file3: URL!
    
    override func setUpWithError() throws {
        provider = MockLogFilesProvider()
        
        file1 = fileManager.temporaryDirectory.appendingPathComponent("test1.log", isDirectory: false)
        XCTAssert(fileManager.createFile(atPath: file1.path, contents: "a log".data(using: .utf8), attributes: nil))
        provider.logFiles.append(("Log1", file1))
        
        file2 = fileManager.temporaryDirectory.appendingPathComponent("empty.log", isDirectory: false)
        XCTAssert(fileManager.createFile(atPath: file2.path, contents: nil, attributes: nil))
        provider.logFiles.append(("Log2", file1))
        
        file3 = fileManager.temporaryDirectory.appendingPathComponent("nonexistingfile.log", isDirectory: false)
        provider.logFiles.append(("Log3", file3))
        
        viewModel = LogSelectionViewModel(logFileProvider: provider)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: file1)
        try? fileManager.removeItem(at: file2)
    }
    
    func testViewModelCreatesCellsOnlyForExistingLogs() throws {
        XCTAssert(viewModel.tableViewData.count == 1)
        XCTAssert(viewModel.tableViewData.first?.cells.count == 2) // Log3 should be ignored as there is no such file
    }
    
    func testHandlerOpensCorrectLog() throws {
        var openedTitle = ""
        var openedUrl = URL(string: "nofile")
        
        viewModel.pushHandler = { logsViewModel in
            openedTitle = logsViewModel.title
            openedUrl = logsViewModel.logFile
        }
        
        let cell = viewModel.tableViewData.first?.cells.first
        switch cell {
        case .pushStandard(let title, let handler):
            XCTAssertEqual(title, "Log1")
            handler()
            XCTAssertEqual(openedTitle, "Log1")
            XCTAssertEqual(openedUrl, file1)
            
        default:
            XCTAssert(false, "Wrong cell type returned")
        }
        
    }

}
