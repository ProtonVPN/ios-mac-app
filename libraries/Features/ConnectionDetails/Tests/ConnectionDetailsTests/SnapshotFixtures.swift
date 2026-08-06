//
//  Created on 06/08/2026 by Max Kupetskyi.
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

import Connection
import Domain
import Foundation

/// Shared state for the connection-details snapshot suites, so every reference image is rendered from
/// the same connection.
enum SnapshotFixtures {
    /// The locale the suites pin, so localized country names don't follow the machine that recorded
    /// the references — and so `@Dependency(\.locale)` isn't read live from a test.
    static let locale = Locale(identifier: "en_US")

    /// Where the reference images live on CI, relative to the repository root.
    static let testsDirectory = "libraries/Features/ConnectionDetails/Tests/ConnectionDetailsTests"

    /// A typical phone width; the views are laid out against it and take their natural height.
    static let phoneWidth: CGFloat = 393

    /// When the snapshotted session started.
    ///
    /// Deliberately more than a day ago: `sessionLengthText` renders sub-day durations down to the
    /// second, which would change between recording a reference and verifying against it. Past a day it
    /// renders days and hours, and the half-hour offset keeps the rendered value away from the boundary
    /// where it would tick over mid-suite.
    static var connectedSince: Date {
        Date(timeIntervalSinceNow: -(2 * 86400 + 3 * 3600 + 1800))
    }

    /// A connected state on `server`, with the exit address the local agent reports for it.
    static func connected(
        server: Server = server(),
        agentExitIP: String? = "185.159.157.42"
    ) -> ConnectionState {
        .connected(
            .init(
                connectionSpec: ConnectionSpec(location: .country(code: "PL", order: .fastest), features: []),
                tunnelProtocol: .wireGuard,
                peerIDs: ["peer-id"],
                killSwitch: false
            ),
            .init(
                currentPeer: server,
                connectionDate: connectedSince,
                protocolConnectionData: .proTUN(.init(transport: .udp, serverExitV4: agentExitIP))
            )
        )
    }

    /// A connected state whose spec and server are both Secure Core, so the screen shows the entry hop
    /// and the Secure Core feature panel.
    static func connectedToSecureCore() -> ConnectionState {
        .connected(
            .init(
                connectionSpec: ConnectionSpec(location: .secureCore(.hop(to: "PL", via: "CH")), features: []),
                tunnelProtocol: .wireGuard,
                peerIDs: ["peer-id"],
                killSwitch: false
            ),
            .init(
                currentPeer: server(features: .secureCore, name: "CH-PL#2", entryCountryCode: "CH"),
                connectionDate: connectedSince,
                protocolConnectionData: .proTUN(.init(transport: .udp, serverExitV4: "185.159.157.42"))
            )
        )
    }

    /// - Note: spelled out rather than taken from `Server.mock`, which drops the feature set it is given.
    static func server(
        features: ServerFeature = [.p2p, .streaming],
        name: String = "PL#42",
        entryCountryCode: String = "PL"
    ) -> Server {
        Server(
            logical: Logical(
                id: "logical-id",
                name: name,
                domain: "node-pl-42.protonvpn.net",
                load: 42,
                entryCountryCode: entryCountryCode,
                exitCountryCode: "PL",
                tier: .paid,
                score: 1,
                status: 1,
                feature: features,
                city: "Warsaw",
                state: nil,
                hostCountry: nil,
                translatedCity: "Warsaw",
                latitude: 52.229675,
                longitude: 21.012231,
                gatewayName: nil
            ),
            endpoint: ServerEndpoint(
                id: "endpoint-id",
                entryIp: "185.159.157.1",
                exitIp: "185.159.157.40",
                domain: "node-pl-42.protonvpn.net",
                status: 1,
                label: "2",
                x25519PublicKey: nil,
                protocolEntries: nil
            )
        )
    }
}
