//
//  Created on 2023-11-21.
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

/// Actor that can be used to count something in a thread-safe way.
/// Starts counting from 0.
public actor CounterActor {
    var value = 0

    /// Increments value by 1
    public func increment() {
        value += 1
    }

    /// Resets value back to zero
    public func reset() {
        value = 0
    }
}
