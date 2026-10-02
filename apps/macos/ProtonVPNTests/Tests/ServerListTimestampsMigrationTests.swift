//
//  Created on 28/09/2026 by Max Kupetskyi.
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

import Dependencies
import Ergonomics
import Foundation
import Persistence
@testable import ProtonVPN
import Sharing
import Testing

/// The 6.5.2 update deletes the stored `Last-Modified` values once. The next server list request then downloads the
/// full list with its IKEv2 entries, instead of keeping an older list through 304 responses.
struct ServerListTimestampsMigrationTests {
    private let lastModified = "Mon, 28 Sep 2026 10:00:00 GMT"

    /// Runs the migration step with both values stored, starting from `previousVersion`, and returns what is left.
    private func storedTimestamps(afterMigratingFrom previousVersion: String) async throws -> [String?] {
        let repository = withDependencies {
            $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
        } operation: {
            ServerRepositoryKey.liveValue
        }
        repository.setMetadata(lastModified, for: .lastModifiedFree)
        repository.setMetadata(lastModified, for: .lastModifiedAll)

        try await withDependencies {
            $0.defaultAppStorage = try #require(UserDefaults(suiteName: UUID().uuidString))
            $0.serverRepository = repository
        } operation: {
            @Shared(.lastAppVersion) var lastAppVersion
            $lastAppVersion.withLock { $0 = previousVersion }

            try await MigrationManagerImplementation(finalVersion: "6.5.2+3200000.2609281000")
                .checkingServerListTimestamps()
                .migrate()
        }

        return [repository.getMetadata(.lastModifiedFree), repository.getMetadata(.lastModifiedAll)]
    }

    @Test("Updating from 6.5.1 deletes the stored Last-Modified values")
    func updateDeletesTimestamps() async throws {
        let timestamps = try await storedTimestamps(afterMigratingFrom: "6.5.1+3100000.2605011144")

        #expect(timestamps == [nil, nil])
    }

    @Test("A later launch of 6.5.2 keeps the stored Last-Modified values")
    func laterLaunchKeepsTimestamps() async throws {
        let timestamps = try await storedTimestamps(afterMigratingFrom: "6.5.2+3200000.2609281000")

        #expect(timestamps == [lastModified, lastModified])
    }
}
