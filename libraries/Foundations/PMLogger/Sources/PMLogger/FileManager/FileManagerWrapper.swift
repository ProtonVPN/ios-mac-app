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
import os.log

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

    func fileCreationDateSort(lhs: URL, rhs: URL) -> Bool
    func creationDate(of url: URL) -> Date?
}

extension FileManagerWrapper {
    public func fileCreationDateSort(lhs: URL, rhs: URL) -> Bool {
        creationDate(of: lhs)?.timeIntervalSince1970 ?? 0 < creationDate(of: rhs)?.timeIntervalSince1970 ?? 0
    }

    public func creationDate(of url: URL) -> Date? {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try attributesOfItem(atPath: url.path)
        } catch {
            os_log("Failed to get attributes of file at %{public}s with error %{public}s",
                   log: OSLog(subsystem: "PMLogger", category: "FileManager"),
                   type: OSLogType.error,
                   url.path,
                   error as CVarArg)
            return nil
        }

        guard let date = attributes[.creationDate] as? Date else {
            os_log("Attributes of file at %{public}s do not contain creation date",
                   log: OSLog(subsystem: "PMLogger", category: "FileManager"),
                   type: OSLogType.error,
                   url.path)
            return nil
        }
        return date
    }
}

extension FileManager: FileManagerWrapper {
    public func createFileHandle(forWritingTo url: URL) throws -> FileHandleWrapper {
        return try FileHandle(forWritingTo: url)
    }
}
