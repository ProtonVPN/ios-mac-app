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

import Dependencies
@testable import PMLogger
import XCTest

class LogFilesTemporaryStorageTests: XCTestCase {
    func testSavesDataToFileAndDeletesTempFile() throws {
        let contentRequested = XCTestExpectation(description: "Content requested from LogContent")
        let contentSavedToFile = XCTestExpectation(description: "Content saved to temporary file")
        let logContents = "test content"

        let content = LogArchiveContentMock { callback in
            contentRequested.fulfill()
            callback(logContents)
        } archiveHandler: {
            URL(string: "/some/path/that/does/not/exists")!
        }
        #if os(iOS)
            let provider = LogContentProvider { source in
                let data = [LogSource.app: content]
                return data[source]!
            } getArchive: { source in
                let data = [LogSource.app: content]
                return data[source]!
            }
        #else
            let provider = LogContentProvider { source in
                let data = [LogSource.app: content]
                return data[source]!
            }
        #endif

        withDependencies {
            $0.logContentProvider = provider
        } operation: {
            let storage = LogFilesTemporaryStorage(logSources: [LogSource.app])

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
    }

    func testHandlesLogContentTimeout() throws {
        let contentRequested = XCTestExpectation(description: "Content requested from LogContent")
        let contentSavedToFile = XCTestExpectation(description: "Content saved to temporary file")

        let content = LogArchiveContentMock { _ in
            contentRequested.fulfill()
            // Do NOT call the callback
        } archiveHandler: {
            URL(string: "/some/path/that/does/not/exists")!
        }
        #if os(iOS)
            let provider = LogContentProvider { source in
                let data = [LogSource.app: content]
                return data[source]!
            } getArchive: { source in
                let data = [LogSource.app: content]
                return data[source]!
            }
        #else
            let provider = LogContentProvider { source in
                let data = [LogSource.app: content]
                return data[source]!
            }
        #endif

        withDependencies {
            $0.logContentProvider = provider
        } operation: {
            let storage = LogFilesTemporaryStorage(logSources: [LogSource.app], timeout: 0.1)

            storage.prepareLogs(responseHandler: { urls in
                XCTAssertEqual(urls.count, 0)
                XCTAssert(Thread.isMainThread)
                storage.deleteTempLogs()
                contentSavedToFile.fulfill()
            })

            wait(for: [contentRequested, contentSavedToFile], timeout: 1)
        }
    }
}

struct LogArchiveContentMock: LogArchiveContent {
    public var handler: ((String) -> Void) -> Void
    public var archiveHandler: () -> URL

    func loadContent(callback: @escaping (String) -> Void) {
        handler(callback)
    }

    func loadArchive() async -> URL? {
        archiveHandler()
    }
}
