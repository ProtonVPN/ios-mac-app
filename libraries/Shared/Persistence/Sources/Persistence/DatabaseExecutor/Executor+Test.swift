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
import XCTestDynamicOverlay

/// Executor suitable for tests, since it will fail on any uncaught errors during the execution of `operation`.
struct TestDatabaseExecutor: DatabaseExecutor {
    func execute<T>(operation: () throws -> T, fallback: T) -> T {
        do {
            return try operation()
        } catch {
            XCTFail("Unhandled error: \(error)")
            return fallback
        }
    }
}
