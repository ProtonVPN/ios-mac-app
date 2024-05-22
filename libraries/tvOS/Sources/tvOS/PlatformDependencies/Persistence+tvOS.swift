//
//  Created on 09/05/2024.
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
import Dependencies
import Persistence

// MARK: Live implementations of app dependencies

extension DatabaseConfiguration {

    /// Database configuration suitable for both debug and release builds.
    ///  - Database file located in Application Support directory
    ///  - Errors during database operations after initialisation are caught
    ///  - Operations resulting in an error fall back to returning default values
    ///
    ///  - Note: duplicates DatabaseConfiguration.live from LegacyCommon, with the omission
    ///     of logging and Sentry error reporting.
    public static var live: DatabaseConfiguration {
        let directoryURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let directoryURL = directoryURLs.first else {
            fatalError("Failed to initialise app DB: cannot find URL for application support directory")
        }

        if !FileManager.default.fileExists(atPath: directoryURL.absolutePath) {
            try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let databasePath = directoryURL
            .appendingPathComponent("database")
            .appendingPathExtension("sqlite")
            .absolutePath

        let executor = ErrorHandlingAndLoggingDatabaseExecutor(
            logError: { message, error in
                print("Persistence: \(message), \(error)")
                // log.error("\(message)", category: .persistence, metadata: ["error": "\(String(describing: error))"])
                // SentryHelper.shared?.log(error: error)
            }
        )

        return DatabaseConfiguration(
            executor: executor,
            databaseType: .physical(filePath: databasePath),
            schemaVersion: .latest
        )
    }
}


extension DatabaseConfigurationKey: DependencyKey {
    public static let liveValue: DatabaseConfiguration = .live
}
