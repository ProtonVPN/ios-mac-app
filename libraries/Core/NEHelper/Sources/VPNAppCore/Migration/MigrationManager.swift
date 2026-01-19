//
//  Created on 23.12.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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
import Domain
import Ergonomics
import Foundation

extension MigrationManagerImplementation: @retroactive DependencyKey {
    public static let liveValue: MigrationManager = MigrationManagerImplementation()
        .checking(.platform(iOS: "4.1.18", macOS: "3.0.15")) { _ in
            @Dependency(\.defaultsProvider) var provider
            let defaults = provider.getDefaults()
            let key = "servers"
            if defaults.data(forKey: key) != nil {
                log.debug("Removing value for key \(key)", category: .persistence)
                defaults.removeObject(forKey: key)
            }
        }
        .checkingConnectionSpec()
}
