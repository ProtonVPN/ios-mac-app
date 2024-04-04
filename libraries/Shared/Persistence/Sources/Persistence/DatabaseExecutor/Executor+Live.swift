//
//  Created on 03/03/2024.
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

/// Handles most programmer errors such as uncaught SQLite errors resulting from constraint violations.
/// Crashes in DEBUG builds for awareness, logging errors and defaulting to fallback values in RELEASE builds.
/// `TestDatabaseExecutor` should be used during tests.
///
/// For more information about types of potential errors thrown within `operation`, visit:
/// [Error Handling](https://github.com/groue/GRDB.swift/blob/master/README.md#error-handling)
public struct ErrorHandlingAndLoggingDatabaseExecutor: DatabaseExecutor {
    let logError: ((String, Error) -> Void)?

    public init(logError: @escaping (String, Error) -> Void) {
        self.logError = logError
    }

    public func execute<T>(operation: () throws -> T, fallback: T) -> T {
        do {
            // Note: GRDB operations can also fatalError()
            // This helps "uncover programmer errors, false assumptions, and prevent misuses"
            return try operation()
        } catch let error as DatabaseError {
            // DatabaseErros: mostly SQLite errors e.g. constraint violations
            // Also includes errors thrown from custom database functions (see `convertCodeToLocalizedCountryName`)
            logError?("Caught DatabaseError", error)
            assertionFailure("DatabaseError are thrown on SQLite errors and should be handled inside `operation`")

        } catch let error as RecordError {
            // RecordErrors: attempting to update a record that doesn't exist, or modifying one inside read transactions
            logError?("Caught RecordError", error)
            assertionFailure("Record errors should be handled inside `operation`")

        } catch {
            // From GRDB docs: GRDB can throw DatabaseError, RecordError, or crash your program with a fatal error.
            // Since we are catching Database and Record errors above, we should never trigger this block.
            logError?("Uncaught persistence error", error)
            assertionFailure("Unexpected error: \(error)")
        }

        return fallback
    }
}
