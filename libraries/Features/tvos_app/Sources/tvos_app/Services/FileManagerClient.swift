//
//  Created on 23/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct FileManagerClient: Sendable {
    public var removeItem: @Sendable (_ at: URL) throws -> Void
    public var moveItem: @Sendable (_ from: URL, _ to: URL) throws -> Void
    public var fileExists: @Sendable (_ at: String) -> Bool = { _ in false }
    public var createDirectory: @Sendable (_ at: URL, _ withIntermediateDirectories: Bool) throws -> Void
}

extension FileManagerClient: DependencyKey {
    public static let liveValue = FileManagerClient(
        removeItem: { url in
            try FileManager.default.removeItem(at: url)
        },
        moveItem: { fromURL, toURL in
            try FileManager.default.moveItem(at: fromURL, to: toURL)
        },
        fileExists: { path in
            FileManager.default.fileExists(atPath: path)
        },
        createDirectory: { url, withIntermediateDirectories in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    )
}

public extension DependencyValues {
    var fileManagerClient: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
