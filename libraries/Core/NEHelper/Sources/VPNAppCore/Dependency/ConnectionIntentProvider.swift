//
//  Created on 09/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import DependenciesMacros
import Domain

@DependencyClient
public struct ConnectionIntentStorage: TestDependencyKey, Sendable {
    public internal(set) var getConnectionIntent: @Sendable () throws -> ServerConnectionIntent
    public internal(set) var set: @Sendable (_ connectionIntent: ServerConnectionIntent) throws -> Void

    public static let testValue = ConnectionIntentStorage()

    public static let storageKey: String = "ServerConnectionIntent"

    public init(
        getConnectionIntent: @escaping @Sendable () -> ServerConnectionIntent,
        set: @escaping @Sendable (_: ServerConnectionIntent) -> Void
    ) {
        self.getConnectionIntent = getConnectionIntent
        self.set = set
    }
}

public extension DependencyValues {
    var connectionIntentStorage: ConnectionIntentStorage {
        get { self[ConnectionIntentStorage.self] }
        set { self[ConnectionIntentStorage.self] = newValue }
    }
}
