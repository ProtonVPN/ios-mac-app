//
//  Created on 25.06.2026 by John Biggs.
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

import Foundation

/// The all-zeros value of a trivial type.
public func zero<Value: BitwiseCopyable>(value _: Value.Type) -> Value {
    withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Value>.size, alignment: MemoryLayout<Value>.alignment) { raw in
        raw.initializeMemory(as: UInt8.self, repeating: 0)
        return raw.loadUnaligned(as: Value.self)
    }
}
