//
//  Created on 07/07/2026 by Max Kupetskyi.
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

@testable import Announcement
import Dependencies
import Foundation
import Sharing
import Testing
import VPNShared

@Suite(.serialized)
struct AnnouncementRefresherImplementationTests {
    /// Counts how many times the mocked API endpoint was hit (from the refresher's detached `Task`)
    private actor CallCounter {
        private(set) var count = 0
        func increment() {
            count += 1
        }
    }

    // MARK: - Helpers

    private func withStorage<T>(_ body: () async -> T) async -> T {
        let suiteName = "AnnouncementRefresherImplementationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername("test-user")
        return await withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            @Shared(.lastAnnouncementRefreshDate) var lastRefreshDate: Date?
            @Shared(.announcements) var announcements: [Announcement]?
            $lastRefreshDate.withLock { $0 = nil }
            $announcements.withLock { $0 = nil }
            return await body()
        }
    }

    private func seed(_ announcements: [Announcement]) {
        @Shared(.announcements) var stored: [Announcement]?
        $stored.withLock { $0 = announcements }
    }

    private func stored() -> [Announcement] {
        @SharedReader(.announcements) var stored: [Announcement]?
        return stored ?? []
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () async -> Bool) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func announcement(_ id: String, type: Announcement.NotificationType) -> Announcement {
        Announcement(
            notificationID: id,
            startTime: Date(),
            endTime: Date(),
            type: type.rawValue,
            offer: nil,
            reference: nil
        )
    }

    // MARK: - Tests

    @Test
    func callsAPIOnRefresh() async {
        await withStorage {
            let counter = CallCounter()
            await withDependencies {
                $0.announcementClient = .init {
                    await counter.increment()
                    return .init(notifications: [])
                }
            } operation: {
                let refresher = AnnouncementRefresherImplementation()
                refresher.tryRefreshing()
                await waitUntil { await counter.count >= 1 }
                #expect(await counter.count == 1)
            }
        }
    }

    @Test
    func doesNotRefreshTooOften() async {
        await withStorage {
            let counter = CallCounter()
            await withDependencies {
                $0.announcementClient = .init {
                    await counter.increment()
                    return .init(notifications: [])
                }
            } operation: {
                let refresher = AnnouncementRefresherImplementation()
                refresher.tryRefreshing()
                await waitUntil { await counter.count >= 1 }

                // Second call is within the default throttle interval, so it must not refresh again.
                refresher.tryRefreshing()
                await waitUntil(timeout: .milliseconds(100)) { await counter.count >= 2 }
                #expect(await counter.count == 1)
            }
        }
    }

    @Test
    func refreshesAfterMinTimePassed() async {
        await withStorage {
            let counter = CallCounter()
            await withDependencies {
                $0.announcementClient = .init {
                    await counter.increment()
                    return .init(notifications: [])
                }
            } operation: {
                // A zero interval disables the throttle, so both calls refresh.
                let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)
                refresher.tryRefreshing()
                refresher.tryRefreshing()
                await waitUntil { await counter.count >= 2 }
                #expect(await counter.count == 2)
            }
        }
    }

    @Test
    func savesNewAnnouncementsToStorage() async {
        await withStorage {
            seed([
                announcement("oldDefault", type: .default),
                announcement("oldOneTime", type: .oneTime),
            ])

            await withDependencies {
                $0.announcementClient = .init {
                    .init(notifications: [
                        announcement("newDefault", type: .default),
                        announcement("newOneTime", type: .oneTime),
                    ])
                }
            } operation: {
                let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

                #expect(stored().containsAnnouncement(withId: "oldDefault"))
                #expect(stored().containsAnnouncement(withId: "oldOneTime"))
                #expect(!stored().containsAnnouncement(withId: "newDefault"))
                #expect(!stored().containsAnnouncement(withId: "newOneTime"))

                refresher.tryRefreshing()
                await waitUntil { stored().containsAnnouncement(withId: "newDefault") }

                #expect(!stored().containsAnnouncement(withId: "oldDefault"))
                #expect(!stored().containsAnnouncement(withId: "oldOneTime"))
                #expect(stored().containsAnnouncement(withId: "newDefault"))
                #expect(stored().containsAnnouncement(withId: "newOneTime"))
            }
        }
    }

    @Test
    func doesntSaveNewAnnouncementsToStorageOnError() async {
        await withStorage {
            let counter = CallCounter()
            seed([
                announcement("oldDefault", type: .default),
                announcement("oldOneTime", type: .oneTime),
            ])

            await withDependencies {
                $0.announcementClient = .init {
                    await counter.increment()
                    throw CancellationError()
                }
            } operation: {
                let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

                #expect(stored().count == 2)

                refresher.tryRefreshing()
                // Wait until the API was hit (and threw); storage must be left untouched.
                await waitUntil { await counter.count >= 1 }

                #expect(stored().containsAnnouncement(withId: "oldDefault"))
                #expect(stored().containsAnnouncement(withId: "oldOneTime"))
                #expect(stored().count == 2)
            }
        }
    }
}
