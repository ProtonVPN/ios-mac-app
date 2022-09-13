//
//  Created on 2021-11-24.
//
//  Copyright (c) 2021 Proton AG
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

// Extension to use updated methods on OSes that support them
extension FileHandle {
    public func seekToEndCustom() throws -> UInt64 {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            return try seekToEnd()
        } else {
            return seekToEndOfFile()
        }
    }
    
    public func writeCustom(contentsOf data: Data) throws {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            try write(contentsOf: data)
        } else {
            write(data)
        }
    }
    
    public func synchronizeCustom() throws {
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            try synchronize()
        } else {
            synchronizeFile()
        }
    }
    
    public func closeCustom() throws {
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            try close()
        } else {
            closeFile()
        }
    }
}
