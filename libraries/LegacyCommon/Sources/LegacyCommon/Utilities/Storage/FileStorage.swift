//
//  Created on 09/03/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Dependencies
import VPNShared

// File-based DataStorage, suitable for persisting large amounts of data
public class FileStorage {
    private let buildURL: (String) throws -> URL

    public init(urlBuilder: @escaping (String) throws -> URL) {
        self.buildURL = urlBuilder
    }

    public func store(_ data: Data, forKey key: String) throws {
        let url = try buildURL(key)
        try data.write(to: url, options: .atomic)
        log.debug("Wrote \(data.count) bytes while saving value for \(key) at \(url)", category: .persistence)
    }

    public func getData(forKey key: String) throws -> Data {
        let url = try buildURL(key)
        let data = try Data(contentsOf: url)
        log.debug("Read \(data.count) bytes while loading value for \(key) at \(url)", category: .persistence)
        return data
    }
}

extension FileManager {
    public static var cachesDirectoryURL: URL {
        get throws {
            try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        }
    }
}

extension FileStorage {
    public static var cached: FileStorage {
        FileStorage(urlBuilder: { path in (try FileManager.cachesDirectoryURL).appendingPathComponent(path) })
    }
}

extension DataStorage: DependencyKey {

    public static var liveValue: DataStorage = {
        let cachesDirectoryFileStorage = FileStorage.cached
        return DataStorage(
            storeData: cachesDirectoryFileStorage.store,
            getData: cachesDirectoryFileStorage.getData
        )
    }()
}
