//
//  Created on 06/02/2026 by Max Kupetskyi.
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
import DependenciesMacros
import Foundation
import VPNShared

@DependencyClient
struct SearchStorageNew: Sendable {
    var clear: @Sendable () -> Void
    var get: @Sendable () -> [String] = { [] }
    var save: @Sendable (_ data: [String]) -> Void
}

extension SearchStorageNew: DependencyKey {
    static let liveValue: SearchStorageNew = {
        let key = "RECENT_SEARCHES"

        let searchStorage = SearchStorageNew(
            clear: {
                @Dependency(\.storage) var storage
                storage.removeObject(forKey: key)
            },
            get: {
                @Dependency(\.storage) var storage
                return (try? storage.get([String].self, forKey: key)) ?? []
            },
            save: { data in
                @Dependency(\.storage) var storage
                try? storage.set(data, forKey: key)
            }
        )
        return searchStorage
    }()

    static let testValue: SearchStorageNew = {
        final class StorageBox: @unchecked Sendable {
            private let lock = NSLock()
            private var value: [String] = []

            func clear() {
                lock.lock()
                defer { lock.unlock() }
                value = []
            }

            func get() -> [String] {
                lock.lock()
                defer { lock.unlock() }
                return value
            }

            func set(_ newValue: [String]) {
                lock.lock()
                defer { lock.unlock() }
                value = newValue
            }
        }

        let storedData = StorageBox()

        let storage = SearchStorageNew(
            clear: { storedData.clear() },
            get: { storedData.get() },
            save: { storedData.set($0) }
        )
        return storage
    }()
}

extension DependencyValues {
    var searchStorageNew: SearchStorageNew {
        get { self[SearchStorageNew.self] }
        set { self[SearchStorageNew.self] = newValue }
    }
}
