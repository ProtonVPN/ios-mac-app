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

/// Performs the bitwise OR operation on a collection of values. These values are allowed to be nil.
/// If no values are passed, or all values passed are nil, nil is returned as the result.
let bitwiseOr = DatabaseFunction(
    "BIT_OR",
    argumentCount: 1,
    pure: true,
    aggregate: BitwiseOR.self
)

/// Performs the bitwise AND operation on a collection of values. These values are allowed to be nil.
/// If no values are passed, or all values passed are nil, nil is returned as the result.
let bitwiseAnd = DatabaseFunction(
    "BIT_AND",
    argumentCount: 1,
    pure: true,
    aggregate: BitwiseAND.self
)

private struct BitwiseOR: DatabaseAggregate {
    var accumulatedValue: Int?

    mutating func step(_ dbValues: [DatabaseValue]) {
        guard let nextValue = Int.fromDatabaseValue(dbValues[0]) else { return }

        accumulatedValue = (accumulatedValue ?? nextValue) | nextValue
    }

    func finalize() -> DatabaseValueConvertible? {
        accumulatedValue
    }
}

private struct BitwiseAND: DatabaseAggregate {
    var accumulatedValue: Int?

    mutating func step(_ dbValues: [DatabaseValue]) {
        guard let nextValue = Int.fromDatabaseValue(dbValues[0]) else { return }

        accumulatedValue = (accumulatedValue ?? nextValue) & nextValue
    }

    func finalize() -> DatabaseValueConvertible? {
        accumulatedValue
    }
}
