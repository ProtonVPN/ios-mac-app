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
    var initializeStorage: () -> Void = { unimplemented() }
    var updateList: (ConnectionSpec) -> Void = { _ in unimplemented() }
    var pin: (RecentConnection) -> Void = { _ in unimplemented() }
    var unpin: (RecentConnection) -> Void = { _ in unimplemented() }
    var remove: (RecentConnection) -> Void = { _ in unimplemented() }
    public var elements: () -> OrderedSet<RecentConnection> = { unimplemented(placeholder: []) }
}

extension RecentsStorage: DependencyKey {
    public static var liveValue: RecentsStorage = {
        let storage = RecentsStorageImplementation()
        return RecentsStorage(
            initializeStorage: storage.initializeStorage,
            updateList: storage.updateList(with:),
            pin: storage.pin(recent:),
            unpin: storage.unpin(recent:),
            remove: storage.remove(recent:),
            elements: storage.elements
        )
    }()
}

extension DependencyValues {
    public var recentsStorage: RecentsStorage {
      get { self[RecentsStorage.self] }
      set { self[RecentsStorage.self] = newValue }
    }
}

extension RecentsStorage: TestDependencyKey {
    public static let testValue = RecentsStorage {

    } updateList: { _ in

    } pin: { _ in

    } unpin: { _ in

    } remove: { _ in

    } elements: {
        RecentsStorageImplementation(array: RecentConnection.sampleData).elements()
    }

    public static func withElements(array: [RecentConnection]) -> RecentsStorage {
        RecentsStorage(elements: { .init(array) })
    }

    public static let previewValue = RecentsStorage {

    } updateList: { _ in

    } pin: { _ in

    } unpin: { _ in

    } remove: { _ in

    } elements: {
        RecentsStorageImplementation(array: RecentConnection.sampleData).elements()
    }
}
