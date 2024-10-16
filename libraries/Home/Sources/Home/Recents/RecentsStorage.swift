//
//  Created on 08/10/2024.
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

import Domain
import Dependencies
import OrderedCollections

public struct RecentsStorage {
    let userID: String
    public var array: OrderedSet<RecentConnection>

    private static let storageKeyPrefix = "RecentConnections"

    @Dependency(\.storage) var storage

    public init(array: [RecentConnection]) {
        self.userID = ""
        self.array = OrderedSet(array)
        self.array.sanitize()
    }

    public init(userID: String = "") {
        self.userID = userID
        self.array = Self.readFromStorage(userID)
    }

    static func storageKey(_ userID: String) -> String {
        Self.storageKeyPrefix + userID
    }

    func saveToStorage() {
        do {
            try storage.set(array, forKey: Self.storageKey(userID))
        } catch {
            log.error("Failed to save recent connections to storage with error: \(error.localizedDescription)",
                      category: .persistence)
        }
    }

#if targetEnvironment(simulator)
    static var simSeedRecents: OrderedSet<RecentConnection> {
        [.connectionRegion,
         .connectionRegionPinned,
         .connectionSecureCore,
         .connectionSecureCoreFastest,
         .defaultFastest,
         .pinnedConnection,
         .previousConnection,
         .previousFreeConnection]
    }
#endif

    static func readFromStorage(_ userID: String) -> OrderedSet<RecentConnection> {
        @Dependency(\.storage) var storage
        var recents: OrderedSet<RecentConnection>
        do {
            recents = try storage.get(OrderedSet<RecentConnection>.self, forKey: storageKey(userID)) ?? []
        } catch {
            log.error("Failed to decode recent connections with error: \(error.localizedDescription)", category: .persistence)
            recents = []
        }
#if targetEnvironment(simulator)
        if recents.isEmpty {
            recents = simSeedRecents
        }
#endif
        return recents
    }

    public mutating func updateList(with spec: ConnectionSpec) {
        array.updateList(with: spec)
        saveToStorage()
    }

    public mutating func pin(spec: ConnectionSpec) {
        array.pin(spec: spec)
        saveToStorage()
    }

    public mutating func unpin(spec: ConnectionSpec) {
        array.unpin(spec: spec)
        saveToStorage()
    }

    public mutating func remove(spec: ConnectionSpec) {
        array.remove(spec: spec)
        saveToStorage()
    }
}

extension OrderedSet<RecentConnection> {

    private static let maxConnections = 8

    func index(for spec: ConnectionSpec) -> Self.Index? {
        firstIndex(where: {  $0.connection == spec })
    }

    mutating func sanitize() {
        while count > Self.maxConnections,
              let index = lastIndex(where: \.notPinned) {
            remove(at: index)
        }
        sort { lhs, rhs in
            if lhs.pinned && !rhs.pinned {
                return true
            }
            if !lhs.pinned && rhs.pinned {
                return false
            }
            return lhs.connectionDate > rhs.connectionDate
        }
    }

    public var mostRecent: RecentConnection? {
        first
    }

    public var connectionsList: [RecentConnection] {
        guard count > 1 else {
            return []
        }
        return Array(dropFirst())
    }

    mutating func updateList(with spec: ConnectionSpec) {
        var oldRecent: RecentConnection?
        if let index = index(for: spec) {
            oldRecent = remove(at: index)
        }
        @Dependency(\.date) var date

        let recent = RecentConnection(
            pinned: oldRecent?.pinned ?? false,
            underMaintenance: oldRecent?.underMaintenance ?? false,
            connectionDate: date(),
            connection: spec
        )

        insert(recent, at: 0)
        sanitize()
    }

    mutating func unpin(spec: ConnectionSpec) {
        updatePin(spec: spec, shouldPin: false)
    }

    mutating func pin(spec: ConnectionSpec) {
        updatePin(spec: spec, shouldPin: true)
    }

    private mutating func updatePin(spec: ConnectionSpec, shouldPin: Bool) {
        guard let index = index(for: spec) else {
            return
        }
        var recent = self[index]
        remove(recent)
        recent.pinned = shouldPin
        insert(recent, at: 0)
        sanitize()
    }

    mutating func remove(spec: ConnectionSpec) {
        removeAll { $0.connection == spec }
    }
}

extension RecentsStorage: Equatable {
    public static func == (lhs: RecentsStorage, rhs: RecentsStorage) -> Bool {
        lhs.userID == rhs.userID
    }
}
