//
//  Created on 09/06/2026 by Max Kupetskyi.
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
import Domain
import ProTUNExtension
import Sharing

final class PacketTunnelProvider: ProTUNPacketTunnelProvider {
    override init() {
        prepareDependencies {
            // Align swift-sharing's default store with the legacy `defaultsProvider` (app-group
            // suite) so `@Shared` keys read the same UserDefaults values as the containing app.
            $0.defaultAppStorage = .domainUserDefaults
        }
        super.init()
    }
}
