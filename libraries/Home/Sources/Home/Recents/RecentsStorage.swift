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
    var readFromStorage: () -> OrderedSet<RecentConnection> = { unimplemented(placeholder: []) }
    var saveToStorage: (OrderedSet<RecentConnection>) -> Void = { _ in unimplemented() }
}

extension RecentsStorage: DependencyKey {
    public static var liveValue: RecentsStorage = {
        return RecentsStorage(
            readFromStorage: RecentsStorageImplementation.readFromStorage,
            saveToStorage: RecentsStorageImplementation.saveToStorage
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
        []
    } saveToStorage: { _ in

    }

    public static func withElements(array: [RecentConnection]) -> RecentsStorage {
        RecentsStorage {
            OrderedSet(array)
        } saveToStorage: { _ in
            
        }
    }

    public static let previewValue = RecentsStorage {
        OrderedSet(RecentConnection.sampleData)
    } saveToStorage: { _ in

    }
}
