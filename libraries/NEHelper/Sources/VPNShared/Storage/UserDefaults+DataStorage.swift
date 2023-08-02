//
//  Created on 13/03/2023.
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

/// Temporary utility extension - never store large amounts of data using UserDefaults, especially in XPC space
extension UserDefaults: DataStorage {

    // Maximum allowed data size, storable under one key in User Defaults
    private var maximumDataSizeBytes: Int { 512 * 1024 } // 512 KiB

    // Storing data exceeding this size will emit a warning
    private var warningDataSizeBytes: Int { 32 * 1024 } // 32 KiB

    public func store(_ data: Data, forKey key: String) throws {
        if data.count > warningDataSizeBytes {
            log.warning("Storing suspiciously large amount of data in User Defaults \(data.count)", category: .persistence)
            assertionFailure("User Defaults writes surpassing \(data.count) bytes should be investigated")
        }
        if data.count > maximumDataSizeBytes {
            throw StorageError.dataTooLarge
        }
        set(data, forKey: key)
    }

    public func getData(forKey key: String) throws -> Data {
        guard let data = data(forKey: key) else {
            throw StorageError.missingData
        }
        return data
    }

    enum StorageError: Error {
        case missingData
        case dataTooLarge
    }
}
