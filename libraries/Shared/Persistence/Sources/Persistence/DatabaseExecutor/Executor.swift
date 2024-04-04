//
//  Created on 01/03/2024.
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

/// Define a database operation executor which handles logging, and allows a mechanism to be provided for catching and
/// recovering from programmer errors in release builds.
///
/// Trusted database based on record types, high test coverage and alpha/beta releases give high confidence that all
/// operations defined in `ServerRepository` already respect the schema and catch `DatabaseError` and `RecordError`,
/// where such errors are possible given the statements executed within.
///
/// `DatabaseExecutor` provides an extra safety net to fall back on in case the above practices leave an edge case
/// uncaught.
///
/// `DatabaseExecutor` must be a protocol-based dependency since `execute` has a generic argument `T`
public protocol DatabaseExecutor {

    /// Execute a database operation, according to some strategy for logging, handling, and recovering from errors.
    ///
    /// - Parameters:
    ///   - operation: Throwing database operation
    ///   - fallback: Default value to fall back to in RELEASE builds, on encountering an uncaught error
    /// - Returns: Either the result of `operation`, or `fallback` if an unexpected error was caught
    func execute<T>(operation: () throws -> T, fallback: T) -> T
}

extension DatabaseExecutor {
    public func execute(operation: () throws -> Void) {
        execute(operation: operation, fallback: ())
    }

    public func execute<T: DatabaseExecutorResult>(operation: () throws -> T, fallback: T? = nil) -> T {
        execute(operation: operation, fallback: fallback ?? T.fallbackValue)
    }
}

public protocol DatabaseExecutorResult {
    static var fallbackValue: Self { get }
}

extension Int: DatabaseExecutorResult {
    public static let fallbackValue = 0
}

extension Array: DatabaseExecutorResult {
    public static var fallbackValue: Self { [] }
}

extension Optional: DatabaseExecutorResult {
    public static var fallbackValue: Self { nil }
}
