//
//  Created on 24/07/2026.
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

#if !os(tvOS)
    import Domain
    import DomainTestSupport
    import Ergonomics
    import Foundation
    import Testing
    @testable import VPNAppCore

    struct ConnectionIntentMigrationTests {
        private let manager: MigrationManager = MigrationManagerImplementation()

        private var storedFeatures: LocalTunnelFeatures {
            LocalTunnelFeatures(killSwitchMode: .advanced, excludeLocalNetworks: true)
        }

        /// The features used to live inside the WireGuard payload. Whichever old shape they arrive in, they have to end
        /// up on the intent itself, where every protocol reads them.
        @Test("V2 intent carries its tunnel features up onto the intent")
        func v2IntentMigrates() throws {
            let v2 = ServerConnectionIntent.V2(
                spec: ConnectionSpec(),
                server: .mock,
                tunnelSettings: .init(transport: .udp, ports: [51820], features: storedFeatures),
                features: .mock
            )
            let migrated = try manager.migrateOldServerConnectionIntent(from: JSONEncoder().encode(v2))
            let intent = try JSONDecoder().decode(ServerConnectionIntent.self, from: migrated)

            #expect(intent.tunnelFeatures == storedFeatures)
            #expect(intent.protocolConfiguration == .wireGuard(WireGuardSettings(backend: .go, transport: .udp)))
        }
    }
#endif
