//
//  Created on 2022-05-20.
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

extension URL {

    /// File size in bytes
    var fileSize: Int? {
        guard let values = try? self.resourceValues(forKeys: [.fileSizeKey]) else {
            return nil
        }
        return values.fileSize
    }

    /// Check if file is not empty
    var isEmpty: Bool {
        return fileSize ?? 0 > 0
    }
}

extension Array where Element == URL {

    /// Check if any of given files is not empty
    public func hasContent() -> Bool {
        return self.first { !$0.isEmpty } != nil
    }

}
