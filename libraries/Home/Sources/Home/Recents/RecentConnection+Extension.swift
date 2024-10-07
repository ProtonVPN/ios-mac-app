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

extension Array<RecentConnection> {
    static let maxConnections = 8

    static let storageKey = "RecentConnections"

    func saveToStorage() {
        @Dependency(\.storage) var storage
        try? storage.set(self, forKey: Self.storageKey)
    }

    static func readFromStorage() -> [RecentConnection] {
        @Dependency(\.storage) var storage
        var recents = (try? storage.get([RecentConnection].self, forKey: storageKey)) ?? []
        recents.trimAndSortList()
        return recents
    }

    func index(for spec: ConnectionSpec) -> Self.Index? {
        firstIndex(where: {  $0.connection == spec })
    }

    mutating func trimAndSortList() {
        while count > Self.maxConnections,
              let index = lastIndex(where: \.notPinned) {
            remove(at: index)
        }

        self = sorted(by: { lhs, rhs in
            if lhs.pinned && !rhs.pinned {
                return true
            }
            if !lhs.pinned && rhs.pinned {
                return false
            }
            return lhs.connectionDate > rhs.connectionDate
        })

        saveToStorage()
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
}
