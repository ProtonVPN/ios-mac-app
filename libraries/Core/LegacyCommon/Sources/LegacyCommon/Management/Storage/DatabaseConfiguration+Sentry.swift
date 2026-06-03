//
//  Created on 04/04/2024.
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
import Persistence
import VPNAppCore

public extension DatabaseConfiguration {
    /// Database configuration suitable for both debug and release builds.
    ///  - Database file located in Application Support directory
    ///  - Errors during database operations after initialisation are caught, logged, reported with sentry
    ///  - Operations resulting in an error fall back to returning default values
    static var live: DatabaseConfiguration {
        let fileManager = FileManager.default
        let directoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.cachesDirectory

        let databaseType: DatabaseType
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let databasePath = directoryURL
                .appendingPathComponent("database")
                .appendingPathExtension("sqlite")
                .absolutePath
            databaseType = .physical(filePath: databasePath)
        } catch {
            log.error(
                "Failed to initialise app DB directory, falling back to ephemeral database",
                category: .persistence,
                metadata: [
                    "path": "\(directoryURL.absolutePath)",
                    "error": "\(error)",
                ]
            )
            assertionFailure("Failed to initialise app DB directory: \(error)")
            SentryHelper.shared?.log(message: "Failed to initialise app DB directory", extra: ["error": "\(error)"])
            databaseType = .ephemeral
        }

        let executor = ErrorHandlingAndLoggingDatabaseExecutor(
            logError: { message, error in
                log.error("\(message)", category: .persistence, metadata: ["error": "\(String(describing: error))"])
                SentryHelper.shared?.log(error: error)
            }
        )

        return DatabaseConfiguration(
            executor: executor,
            databaseType: databaseType,
            schemaVersion: .latest
        )
    }
}
