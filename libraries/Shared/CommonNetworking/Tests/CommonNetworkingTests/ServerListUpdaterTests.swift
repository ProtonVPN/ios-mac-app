//
//  Created on 30/07/2026 by Max Kupetskyi.
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

@testable import CommonNetworking
import Dependencies
import Domain
import Foundation
import Persistence
import PersistenceTestSupport
import Testing

/// Serialized because the updater posts to the process-global default notification center.
@Suite("Server list updater", .serialized)
struct ServerListUpdaterTests {
    // MARK: - Storing servers

    @Test("Keeps servers above the free tier when storing a free tier response")
    func storesFreeTierResponseWithoutPurgingPaidServers() {
        let recorder = RepositoryRecorder()

        let servers = [TestData.createMockServer(withID: "a"), TestData.createMockServer(withID: "b")]
        recorder.update(servers: servers, scope: .freeTier, lastModifiedAt: nil)

        #expect(recorder.replacedServerIDs == [["a", "b"]])
        #expect(recorder.maxTiers == [VpnTier.free.rawValue])
    }

    @Test("Replaces every tier when storing a full server list response")
    func storesFullResponseAcrossAllTiers() {
        let recorder = RepositoryRecorder()

        recorder.update(servers: [TestData.createMockServer(withID: "a")], scope: .allTiers, lastModifiedAt: nil)

        #expect(recorder.maxTiers == [VpnTier.internal.rawValue])
    }

    @Test("Records a successful refresh so the full server list is fetched again in time")
    func recordsSuccessfulRefresh() {
        let recorder = RepositoryRecorder()
        recorder.metadata[.consecutiveSuccessfulRefreshes] = "5"

        recorder.update(servers: [], scope: .freeTier, lastModifiedAt: nil)

        #expect(recorder.metadata[.consecutiveSuccessfulRefreshes] == "6")
    }

    @Test("Posts a notification so observers reload their server lists")
    func postsServerListUpdateNotification() async {
        let recorder = RepositoryRecorder()

        await confirmation("Server list update posted") { posted in
            let observer = NotificationCenter.default.addObserver(
                forName: ServerListUpdateNotification.name,
                object: nil,
                queue: nil
            ) { _ in posted() }
            defer { NotificationCenter.default.removeObserver(observer) }

            recorder.update(servers: [], scope: .freeTier, lastModifiedAt: nil)
        }
    }

    // MARK: - Conditional requests

    @Test("Stores no last modified value when the response carries no timestamp")
    func storesNoBaselineWithoutATimestamp() {
        let recorder = RepositoryRecorder(enableTimestampedLogicals: true)

        recorder.update(servers: [], scope: .allTiers, lastModifiedAt: nil)

        #expect(recorder.metadata[.lastModifiedFree] == nil)
        #expect(recorder.metadata[.lastModifiedAll] == nil)
    }

    @Test("Keeps a guest response's last modified value out of the account baselines")
    func storesGuestBaselineOnItsOwn() {
        let lastModified = "A few moments ago"
        let recorder = RepositoryRecorder(enableTimestampedLogicals: true)

        recorder.update(servers: [], scope: .guestSession, lastModifiedAt: lastModified)

        #expect(recorder.metadata[.lastModifiedGuest] == lastModified)
        #expect(recorder.metadata[.lastModifiedFree] == nil)
        #expect(recorder.metadata[.lastModifiedAll] == nil)
    }

    @Test("Stores the last modified value of a free tier response")
    func storesLastModifiedOfFreeTierResponse() {
        let lastModified = "A few moments ago"
        let recorder = RepositoryRecorder(enableTimestampedLogicals: true)
        recorder.update(servers: [], scope: .freeTier, lastModifiedAt: lastModified)
        #expect(recorder.metadata[.lastModifiedFree] == lastModified)
        // A free tier response says nothing about the paid servers, so it is no baseline for a full request
        #expect(recorder.metadata[.lastModifiedAll] == nil)
    }

    @Test("Stores the last modified value of a full response for both tier scopes")
    func storesLastModifiedOfFullResponse() {
        let lastModified = "A few moments ago"
        let recorder = RepositoryRecorder(enableTimestampedLogicals: true)
        recorder.update(servers: [], scope: .allTiers, lastModifiedAt: lastModified)
        #expect(recorder.metadata[.lastModifiedFree] == lastModified)
        #expect(recorder.metadata[.lastModifiedAll] == lastModified)
    }

    @Test("Does not overwrite the last modified value when the response has none")
    func keepsLastModifiedWhenResponseHasNone() {
        let recorder = RepositoryRecorder(enableTimestampedLogicals: true)
        recorder.update(servers: [], scope: .freeTier, lastModifiedAt: nil)
        #expect(recorder.writtenMetadataKeys == [.consecutiveSuccessfulRefreshes])
    }

    @Test("Only a full response stamps the translations language")
    func onlyFullResponsesStampTranslationsLanguage() {
        let recorder = RepositoryRecorder()
        recorder.update(servers: [], freeServersOnly: true, lastModifiedAt: nil, language: "fr")
        // The refresh policy forces a full fetch after a language change, so a free tier response can
        // only arrive in the language already stored.
        #expect(recorder.metadata[.translationsLanguage] == nil)

        recorder.update(servers: [], freeServersOnly: false, lastModifiedAt: nil, language: "fr")
        #expect(recorder.metadata[.translationsLanguage] == "fr")
    }

    // MARK: - Request baseline

    @Test("Provides the last modified value while the stored language matches the request's")
    func providesBaselineWhenLanguageMatches() {
        let repository = makeRepository(metadata: [
            .lastModifiedFree: "A few moments ago",
            .translationsLanguage: "fr",
        ])
        #expect(repository.logicalsRequestBaseline(freeTier: true, language: "fr") == "A few moments ago")
    }

    @Test("Provides no baseline after a language change, so the response arrives in full")
    func providesNoBaselineAfterLanguageChange() {
        let repository = makeRepository(metadata: [
            .lastModifiedFree: "A few moments ago",
            .translationsLanguage: "en",
        ])
        #expect(repository.logicalsRequestBaseline(freeTier: true, language: "fr") == nil)
    }

    @Test("Provides no baseline when no translations language was recorded")
    func providesNoBaselineWithoutRecordedLanguage() {
        let repository = makeRepository(metadata: [.lastModifiedAll: "A few moments ago"])
        #expect(repository.logicalsRequestBaseline(freeTier: false, language: "en") == nil)
    }

    private func makeRepository(metadata: [DatabaseMetadata.Key: String]) -> ServerRepository {
        var repository = ServerRepository.empty()
        repository.getMetadata = { metadata[$0] }
        return repository
    }
}

/// Records what the live ``ServerListUpdater`` asks of the repository.
///
/// Endpoints that aren't stubbed here are left unimplemented, so touching one fails the test.
private final class RepositoryRecorder: @unchecked Sendable {
    private(set) var replacedServerIDs: [[String]] = []
    private(set) var maxTiers: [Int] = []
    private(set) var writtenMetadataKeys: [DatabaseMetadata.Key] = []
    var metadata: [DatabaseMetadata.Key: String] = [:]

    func update(servers: [VPNServer], freeServersOnly: Bool, lastModifiedAt: String?, language: String = "en") {
        var repository = ServerRepository.empty()
        repository.replaceServers = { [self] servers, maxTier in
            replacedServerIDs.append(servers.map(\.id))
            maxTiers.append(maxTier)
            return 0
        }
        repository.getMetadata = { [self] key in metadata[key] }
        repository.setMetadata = { [self] key, value in
            writtenMetadataKeys.append(key)
            metadata[key] = value
        }

        withDependencies {
            $0.serverRepository = repository
        } operation: {
            ServerListUpdater.liveValue.update(
                servers: servers,
                freeServersOnly: freeServersOnly,
                lastModifiedAt: lastModifiedAt,
                language: language
            )
        }
    }
}
