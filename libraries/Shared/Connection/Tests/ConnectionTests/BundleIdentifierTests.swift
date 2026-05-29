//
//  Created on 15/05/2026 by Max Kupetskyi.
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

#if DEBUG
    import CoreConnection
    import Dependencies
    import class NetworkExtension.NETunnelProviderProtocol
    import Testing

    struct BundleIdentifierTests {
        @Test
        func transparentProxyBundleIsNotTrackedAsVpnManager() {
            let allBundleIdentifiers = withDependencies { _ in
            } operation: {
                @Dependency(\.bundleIDClient) var bundleIDClient
                return bundleIDClient.allBundleIdentifiers()
            }

            #if os(macOS)
                #expect(!allBundleIdentifiers.contains("ch.protonvpn.mac.Transparent-Proxy"))
                #expect(allBundleIdentifiers.contains("ch.protonvpn.mac.WireGuard-Extension"))
            #else
                #expect(allBundleIdentifiers.isEmpty == false)
            #endif
        }
    }
#endif
