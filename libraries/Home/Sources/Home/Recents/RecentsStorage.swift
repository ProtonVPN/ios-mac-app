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
    var updateList: (ConnectionSpec) -> Void = { _ in unimplemented() }
    var pin: (ConnectionSpec) -> Void = { _ in unimplemented() }
    var unpin: (ConnectionSpec) -> Void = { _ in unimplemented() }
    var remove: (ConnectionSpec) -> Void = { _ in unimplemented() }
    var elements: () -> [RecentConnection] = { unimplemented(placeholder: []) }
}

extension RecentsStorage: DependencyKey {
    public static var liveValue: RecentsStorage = {
        @Dependency(\.authKeychain) var authKeychain
        let userID = authKeychain.userId ?? ""
        let storage = RecentsStorageImplementation(userID: userID)
        return RecentsStorage(
            updateList: storage.updateList(with:),
            pin: storage.pin(spec:),
            unpin: storage.unpin(spec:),
            remove: storage.remove(spec:),
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
    public static let testValue = RecentsStorage { spec in

    } pin: { spec in

    } unpin: { spec in

    } remove: { spec in

    } elements: {
        RecentsStorageImplementation(array: RecentConnection.sampleData).elements()
    }
    public static func withElements(array: [RecentConnection]) -> RecentsStorage { RecentsStorage(elements: { array }) }

    public static let previewValue = RecentsStorage { spec in

    } pin: { spec in

    } unpin: { spec in

    } remove: { spec in

    } elements: {
        RecentsStorageImplementation(array: RecentConnection.sampleData).elements()
    }

}
