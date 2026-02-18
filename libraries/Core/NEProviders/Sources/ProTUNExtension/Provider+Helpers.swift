//
//  Created on 18/02/2026 by adam.
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

#if DEBUG && os(iOS)
    import ConnectionShared
    import Foundation

    extension ProTUNPacketTunnelProvider {
        func configurationFromProtocolConfiguration() throws(ProTUNConfigurationError) -> ProTUNConfiguration {
            let configurationData: Data?
            do {
                configurationData = try TunnelKeychainImplementation().loadWireguardConfig()
            } catch {
                throw .loadFromKeychainFailed(error)
            }

            guard let configurationData else {
                throw .configurationMissing
            }

            do {
                return try JSONDecoder().decode(ProTUNConfiguration.self, from: configurationData)
            } catch {
                throw .decodingFailed(error)
            }
        }
    }
#endif
