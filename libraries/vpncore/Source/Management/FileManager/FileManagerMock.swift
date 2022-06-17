//
//  Created on 2022-06-16.
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

import Foundation
import ProtonCore_TestingToolkit
@testable import vpncore

class FileManagerMock: FileManagerWrapper {

    @ThrowingFuncStub(FileManagerMock.createDirectory)  var createDirectoryStub
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try createDirectoryStub(url, createIntermediates, attributes)
    }

    @FuncStub(FileManagerMock.fileExists, initialReturn: false) var fileExistsStub
    func fileExists(atPath path: String) -> Bool {
        fileExistsStub(path)
    }

    @FuncStub(FileManagerMock.createFile, initialReturn: true) var createFileStub
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
        createFileStub(path, data, attr)
    }

    @ThrowingFuncStub(FileManagerMock.moveItem) var moveItemStub
    func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try moveItemStub(srcURL, dstURL)
    }

    @ThrowingFuncStub(FileManagerMock.contentsOfDirectory, initialReturn: []) var contentsOfDirectoryStub
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        try contentsOfDirectoryStub(url, keys, mask)
    }

    @ThrowingFuncStub(FileManagerMock.attributesOfItem, initialReturn: [:]) var attributesOfItemStub
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try attributesOfItemStub(path)
    }

    @ThrowingFuncStub(FileManagerMock.removeItem) var removeItemStub
    func removeItem(at URL: URL) throws {
        try removeItemStub(URL)
    }

    @ThrowingFuncStub(FileManagerMock.createFileHandle, initialReturn: try FileHandleMock(forWritingTo: URL(string: "/file")!)) var createFileHandleStub
    public func createFileHandle(forWritingTo url: URL) throws -> FileHandleWrapper {
        return try createFileHandleStub(url)
    }
}
