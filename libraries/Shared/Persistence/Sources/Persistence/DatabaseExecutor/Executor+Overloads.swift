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

extension DatabaseExecutor {

    /// Convenience function that wraps operation with `dbWriter.write`, useful for reducing nesting
    public func write<T>(
        dbWriter: DatabaseQueue,
        operation: (Database) throws -> T,
        fallback: T
    ) -> T {
        let writeOperation = { try dbWriter.write { try operation($0) } }

        return execute(operation: writeOperation, fallback: fallback)
    }

    /// Convenience function that wraps operation with `dbWriter.write`, useful for reducing nesting
    public func write<T: DatabaseExecutorResult>(
        dbWriter: DatabaseQueue,
        operation: (Database) throws -> T,
        fallback: T? = nil
    ) -> T {
        let writeOperation = { try dbWriter.write { try operation($0) } }

        return execute(operation: writeOperation, fallback: fallback)
    }

    /// Overload of write for operations with a Void return type and hence no fallback value
    public func write(dbWriter: DatabaseQueue, operation: (Database) throws -> Void) {
        execute(operation: { try dbWriter.write { try operation($0) } })
    }

    /// Convenience function that wraps operation with `dbWriter.read`, useful for reducing nesting
    public func read<T>(
        dbWriter: DatabaseQueue,
        operation: (Database) throws -> T,
        fallback: T
    ) -> T {
        execute(operation: { try dbWriter.read { try operation($0) } }, fallback: fallback)
    }

    /// Convenience function that wraps operation with `dbWriter.read`, useful for reducing nesting
    public func read<T: DatabaseExecutorResult>(
        dbWriter: DatabaseQueue,
        operation: (Database) throws -> T,
        fallback: T? = nil
    ) -> T {
        let readOperation = { try dbWriter.write { try operation($0) } }

        return execute(operation: readOperation, fallback: fallback)
    }
}
