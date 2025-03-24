//
//  Created on 24/02/2025.
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

import Connection
import Dependencies
import Domain
import Connection
import VPNAppCore
import VPNShared

extension ConnectionIntentStorage: DependencyKey {
    public static let liveValue: ConnectionIntentStorage = .init(
        getConnectionIntent: {
            @Dependency(\.storage) var storage
            guard let intent = try storage.getForUser(ServerConnectionIntent.self, forKey: Self.storageKey) else {
                throw IntentStorageError.intentMissing
            }
            return intent
        },
        set: { newIntent in
            @Dependency(\.storage) var storage
            try storage.setForUser(newIntent, forKey: Self.storageKey)
        }
    )

    enum IntentStorageError: Error {
        case intentMissing
    }
}
