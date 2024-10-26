//
//  Created on 18/10/2024.
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
import Domain
import OrderedCollections
import Dependencies
import VPNAppCore
import Ergonomics

public final class RecentsStorageImplementation {
    public internal(set) var collection: OrderedSet<RecentConnection>

    private static let storageKeyPrefix = "RecentConnections"

    @Dependency(\.storage) var storage
    @Dependency(\.authKeychain) var authKeychain

    public init(array: [RecentConnection]) {
        self.collection = OrderedSet(array)
        self.collection.sanitize()
    }

    public init() {
        self.collection = Self.readFromStorage()
    }

    public func initializeStorage() {
        self.collection = Self.readFromStorage()
    }

    func elements() -> [RecentConnection] {
        collection.elements
    }

    static func storageKey(_ userID: String) -> String {
        Self.storageKeyPrefix + userID
    }

    private func saveToStorage() {
        do {
            guard let userID = authKeychain.userId else {
                throw GenericError(message: "Couldn't retrieve UserID")
            }
            try storage.set(collection, forKey: Self.storageKey(userID))
        } catch {
            log.error("Failed to save recent connections to storage with error: \(error.localizedDescription)",
                      category: .persistence)
        }
    }

    private static func readFromStorage() -> OrderedSet<RecentConnection> {
        do {
            @Dependency(\.authKeychain) var authKeychain
            guard let userID = authKeychain.userId else {
                throw GenericError(message: "Couldn't retrieve UserID")
            }
            @Dependency(\.storage) var storage
            return try storage.get(OrderedSet<RecentConnection>.self, forKey: storageKey(userID)) ?? []
        } catch {
            log.error("Failed to decode recent connections with error: \(error.localizedDescription)", category: .persistence)
            return []
        }
    }

    public func updateList(with spec: ConnectionSpec) {
        collection.updateList(with: spec)
        saveToStorage()
    }

    public func pin(recent: RecentConnection) {
        collection.pin(recent: recent)
        saveToStorage()
    }

    public func unpin(recent: RecentConnection) {
        collection.unpin(recent: recent)
        saveToStorage()
    }

    public func remove(recent: RecentConnection) {
        collection.remove(recent)
        saveToStorage()
    }
}
