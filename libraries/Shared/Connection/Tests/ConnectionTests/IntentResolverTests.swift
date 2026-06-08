//
//  Created on 14/05/2026 by Max Kupetskyi.
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

@testable import Connection
import Dependencies
import Domain
import DomainTestSupport
import Testing
import VPNShared

struct IntentResolverTests {
    @Test
    func ikeResolutionSkipsPortSelection() async throws {
        let resolveIntent = ConnectionPreparationIntent(
            spec: .defaultFastest,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .all
        )
        let expectedServer = Server.mock

        let resolved = try await withDependencies {
            $0.serverSelector = .init(select: { _, _, _ in expectedServer })
            $0.connectionFeatureProvider = .init(connectionFeatures: { .mock })
        } operation: {
            try await ConnectionIntentResolver.liveValue.resolve(resolveIntent)
        }

        #expect(resolved.server.endpoint.id == expectedServer.endpoint.id)
        switch resolved.protocolConfiguration {
        case .ike:
            break
        default:
            Issue.record("Expected IKE protocol configuration")
        }
    }
}
