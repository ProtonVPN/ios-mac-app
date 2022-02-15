//
//  Created on 2022-02-15.
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
@testable import vpncore

public class FolderLogFilesProviderTests: XCTestCase {

    private let fileManager: FileManager = FileManager.default
    private let tempFolder: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(NSUUID().uuidString, isDirectory: true)

    public override func setUpWithError() throws {
        try? fileManager.removeItem(at: tempFolder)
        try fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true, attributes: nil)
    }

    public override func tearDownWithError() throws {
        try fileManager.removeItem(at: tempFolder)
    }

    func testReturnsAllLogFiles() throws {
        let files = [
            tempFolder.appendingPathComponent("file1.log", isDirectory: false),
            tempFolder.appendingPathComponent("file2.log", isDirectory: false),
            tempFolder.appendingPathComponent("file3.txt", isDirectory: false), // This one should be filtered out
            tempFolder.appendingPathComponent("file4.log", isDirectory: false),
            tempFolder.appendingPathComponent("file5.log", isDirectory: false),
        ]

        for file in files {
            fileManager.createFile(atPath: file.path, contents: nil, attributes: nil)
        }

        let provider = FolderLogFilesProvider(appLogFilename: files.first!.absoluteString)
        let result = provider.logFiles

        XCTAssertEqual(result.count, 4)
    }

}
