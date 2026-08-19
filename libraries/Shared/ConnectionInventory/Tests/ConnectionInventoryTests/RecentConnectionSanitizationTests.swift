//
//  Created on 17/08/2026 by Max Kupetskyi.
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

@testable import ConnectionInventory
import Domain
import Foundation
import OrderedCollections
import Testing

/// `sanitized()` puts every pinned connection first, oldest pin first, then the rest, most recently connected first,
/// and keeps only the first eight entries.
struct RecentConnectionSanitizationTests {
    private static let referenceDate = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a recent connection whose dates are offsets in seconds from ``referenceDate``.
    private static func recent(_ code: String, pinnedAt: TimeInterval?, connectedAt: TimeInterval) -> RecentConnection {
        RecentConnection(
            pinnedDate: pinnedAt.map(referenceDate.addingTimeInterval),
            underMaintenance: false,
            connectionDate: referenceDate.addingTimeInterval(connectedAt),
            connection: ConnectionSpec(location: .country(code: code, order: .fastest), features: [])
        )
    }

    @Test
    func `pinned connections come before unpinned ones`() {
        let unpinned = Self.recent("1", pinnedAt: nil, connectedAt: 100)
        let pinned = Self.recent("2", pinnedAt: 1, connectedAt: 0)
        let recents: OrderedSet = [unpinned, pinned]

        #expect(recents.sanitized() == [pinned, unpinned])
    }

    @Test
    func `pinned connections are ordered by pin date, oldest pin first`() {
        let pinnedLast = Self.recent("1", pinnedAt: 30, connectedAt: 0)
        let pinnedFirst = Self.recent("2", pinnedAt: 10, connectedAt: 0)
        let pinnedSecond = Self.recent("3", pinnedAt: 20, connectedAt: 0)
        let recents: OrderedSet = [pinnedLast, pinnedFirst, pinnedSecond]

        #expect(recents.sanitized() == [pinnedFirst, pinnedSecond, pinnedLast])
    }

    @Test
    func `unpinned connections are ordered by connection date, most recent first`() {
        let oldest = Self.recent("1", pinnedAt: nil, connectedAt: 10)
        let newest = Self.recent("2", pinnedAt: nil, connectedAt: 30)
        let middle = Self.recent("3", pinnedAt: nil, connectedAt: 20)
        let recents: OrderedSet = [oldest, newest, middle]

        #expect(recents.sanitized() == [newest, middle, oldest])
    }

    /// The whole list is regrouped, not just the runs of pinned and unpinned entries it happens to start with.
    @Test
    func `interleaved pinned and unpinned connections are grouped and sorted as a whole`() {
        let unpinnedOldest = Self.recent("1", pinnedAt: nil, connectedAt: 10)
        let pinnedLast = Self.recent("2", pinnedAt: 90, connectedAt: 20)
        let unpinnedNewest = Self.recent("3", pinnedAt: nil, connectedAt: 990)
        let pinnedFirst = Self.recent("4", pinnedAt: 10, connectedAt: 30)
        let recents: OrderedSet = [unpinnedOldest, pinnedLast, unpinnedNewest, pinnedFirst]

        #expect(recents.sanitized() == [pinnedFirst, pinnedLast, unpinnedNewest, unpinnedOldest])
    }

    @Test
    func `list longer than the maximum drops the least recent unpinned connections`() {
        let unpinned = (0 ... 9).map { Self.recent("\($0)", pinnedAt: nil, connectedAt: TimeInterval($0)) }
        let recents = OrderedSet(unpinned)

        #expect(recents.sanitized() == OrderedSet(unpinned.reversed().prefix(8)))
    }

    @Test
    func `pinned connections survive trimming even when they are the least recent`() {
        let pinned = Self.recent("pinned", pinnedAt: 1, connectedAt: 0)
        let unpinned = (1 ... 9).map { Self.recent("\($0)", pinnedAt: nil, connectedAt: TimeInterval($0)) }
        let recents = OrderedSet(unpinned + [pinned])

        let sanitized = recents.sanitized()
        #expect(sanitized.count == 8)
        #expect(sanitized.first == pinned)
    }

    @Test
    func `empty list stays empty`() {
        let recents: OrderedSet<RecentConnection> = []

        #expect(recents.sanitized().isEmpty)
    }
}
