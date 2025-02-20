//
//  Created on 20.02.2025.
//
//  Copyright (c) 2025 Proton AG
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

extension Int {
    public init(charPattern: String) {
        assert(charPattern.count == 4, "Char pattern must have exactly 4 characters")
        self = charPattern.withCString { int8Pointer in
            let int32Pointer = UnsafeRawPointer(int8Pointer).bindMemory(to: Int32.self, capacity: 1)
            return Int(int32Pointer.pointee)
        }
    }
}
