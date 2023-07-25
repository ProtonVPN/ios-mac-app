//
//  Created on 2022-06-07.
//
//  Copyright (c) 2022 Proton AG
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
import PMLogger
@testable import LegacyCommon

class LogFilesTemporaryStorageTests: XCTestCase {

    func testSavesDataToFileAndDeletesTempFile() throws {
        let contentRequested = XCTestExpectation(description: "Content requested from LogContent")
        let contentSavedToFile = XCTestExpectation(description: "Content saved to temporary file")
        let logContents = "test content"

        let content = LogContentMock(handler: { callback in
            contentRequested.fulfill()
            callback(logContents)
        })
        let provider = LogContentProviderMock(data: [LogSource.app: content])
        let storage = LogFilesTemporaryStorage(logContentProvider: provider, logSources: [LogSource.app])

        storage.prepareLogs(responseHandler: { urls in
            let fileContent = try! String(contentsOf: urls[0])
            XCTAssertEqual(fileContent, logContents)
            XCTAssert(Thread.isMainThread)
            storage.deleteTempLogs()
            XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
            contentSavedToFile.fulfill()
        })

        wait(for: [contentRequested, contentSavedToFile], timeout: 1)
    }

    func testHandlesLogContentTimeout() throws {
        let contentRequested = XCTestExpectation(description: "Content requested from LogContent")
        let contentSavedToFile = XCTestExpectation(description: "Content saved to temporary file")

        let content = LogContentMock(handler: { callback in
            contentRequested.fulfill()
            // Do NOT call the callback
        })
        let provider = LogContentProviderMock(data: [LogSource.app: content])
        let storage = LogFilesTemporaryStorage(logContentProvider: provider, logSources: [LogSource.app], timeout: 0.1)

        storage.prepareLogs(responseHandler: { urls in
            XCTAssertEqual(urls.count, 0)
            XCTAssert(Thread.isMainThread)
            storage.deleteTempLogs()
            contentSavedToFile.fulfill()
        })

        wait(for: [contentRequested, contentSavedToFile], timeout: 1)
    }
}

struct LogContentProviderMock: LogContentProvider {

    public var data: [LogSource: LogContent]

    func getLogData(for source: LogSource) -> LogContent {
        return data[source]!
    }
}

struct LogContentMock: LogContent {
    public var handler: ((String) -> Void) -> Void

    func loadContent(callback: @escaping (String) -> Void) {
        handler(callback)
    }
}
