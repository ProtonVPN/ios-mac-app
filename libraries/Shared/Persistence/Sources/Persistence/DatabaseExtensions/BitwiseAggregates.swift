//
//  Created on 16/01/2024.
//
//  Copyright (c) 2024 Proton AG
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

import GRDB

let bitwiseOr = DatabaseFunction(
    "BIT_OR",
    argumentCount: 1,
    pure: true,
    aggregate: BitwiseOR.self
)

let bitwiseAnd = DatabaseFunction(
    "BIT_AND",
    argumentCount: 1,
    pure: true,
    aggregate: BitwiseAND.self
)

struct BitwiseOR: DatabaseAggregate {
    var accumulatedValue: Int = 0

    mutating func step(_ dbValues: [DatabaseValue]) {
        guard let nextValue = Int.fromDatabaseValue(dbValues[0]) else { return }

        accumulatedValue |= nextValue
    }

    func finalize() -> DatabaseValueConvertible? {
        accumulatedValue
    }
}

struct BitwiseAND: DatabaseAggregate {
    var accumulatedValue: Int = -1 // initial value of 0xFF...FF

    mutating func step(_ dbValues: [DatabaseValue]) {
        guard let nextValue = Int.fromDatabaseValue(dbValues[0]) else { return }
        accumulatedValue &= nextValue
    }

    func finalize() -> DatabaseValueConvertible? {
        accumulatedValue
    }
}
