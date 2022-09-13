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

/// Wraps `FileManager` to show what methods we are using and make it possible to mock them in tests
public protocol FileManagerWrapper {

    // Methods from FileManager
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func fileExists(atPath path: String) -> Bool
    @discardableResult func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
    func moveItem(at srcURL: URL, to dstURL: URL) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func removeItem(at URL: URL) throws

    // Custom methods

    // Lets us use `FileHandleWrapper` instead of `FileHandler` directly, so it can also be mocked.
    func createFileHandle(forWritingTo url: URL) throws -> FileHandleWrapper
}

extension FileManager: FileManagerWrapper {
    public func createFileHandle(forWritingTo url: URL) throws -> FileHandleWrapper {
        return try FileHandle(forWritingTo: url)
    }
}
