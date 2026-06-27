//
//  Created on 28/05/2026 by Max Kupetskyi.
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

#if DEBUG && !os(tvOS)
    import Domain
    import Foundation

    public extension ConnectionState {
        /// A `.connected` state matching `spec` — derives exit country / Secure Core / gateway
        /// from `spec.location` so the rendered UI reflects the intent.
        static func previewConnected(for spec: ConnectionSpec) -> ConnectionState {
            .connected(
                .init(connectionSpec: spec, tunnelProtocol: .wireGuard, peerIDs: []),
                .init(
                    currentPeer: .preview(for: spec.location),
                    connectionDate: Date(),
                    protocolConnectionData: .proTUN(.init(transport: .udp))
                )
            )
        }

        static func previewConnected(for spec: ConnectionSpec, server: Server) -> ConnectionState {
            .connected(
                .init(connectionSpec: spec, tunnelProtocol: .wireGuard, peerIDs: []),
                .init(
                    currentPeer: server,
                    connectionDate: Date(),
                    protocolConnectionData: .proTUN(.init(transport: .udp))
                )
            )
        }

        /// A `.connecting(.resolved(...))` state matching `spec`.
        static func previewConnecting(for spec: ConnectionSpec) -> ConnectionState {
            .connecting(.resolved(.init(spec: spec, tunnelProtocol: .wireGuard, resolvedServer: .preview(for: spec.location))))
        }
    }

    public extension ServerConnectionIntent {
        static func preview(for spec: ConnectionSpec) -> ServerConnectionIntent {
            preview(for: spec, server: .preview(for: spec.location))
        }

        static func preview(for spec: ConnectionSpec, server: Server) -> ServerConnectionIntent {
            ServerConnectionIntent(
                spec: spec,
                server: server,
                protocolConfiguration: .wireGuard(WireGuardSettings(
                    backend: .go,
                    transport: .udp,
                    features: LocalTunnelFeatures(killSwitch: false, excludeLocalNetworks: false)
                )),
                features: AgentTunnelFeatures(
                    netshield: .off,
                    vpnAccelerator: true,
                    natType: .default,
                    portForwarding: nil
                )
            )
        }
    }

    public extension Server {
        /// Default preview server — Switzerland, no Secure Core / gateway
        static let preview: Server = .preview(for: .any(.fastest))

        static func preview(for location: ConnectionSpec.Location) -> Server {
            let exitCountry: String
            let isSecureCore: Bool
            let gatewayName: String?
            switch location {
            case let .country(code, _),
                 let .city(_, code, _),
                 let .state(_, code, _):
                exitCountry = code
                isSecureCore = false
                gatewayName = nil
            case let .exact(_, _, _, _, regionCode):
                exitCountry = regionCode
                isSecureCore = false
                gatewayName = nil
            case let .secureCore(.anyHop(toCode, _)),
                 let .secureCore(.hop(toCode, _)):
                exitCountry = toCode
                isSecureCore = true
                gatewayName = nil
            case .secureCore(.any):
                exitCountry = "CH"
                isSecureCore = true
                gatewayName = nil
            case let .gateway(name):
                exitCountry = "CH"
                isSecureCore = false
                gatewayName = name
            case .any:
                exitCountry = "CH"
                isSecureCore = false
                gatewayName = nil
            }
            let logical = Logical(
                id: "preview-logical",
                name: "PREVIEW-\(exitCountry)#1",
                domain: "preview.protonvpn.ch",
                load: 42,
                entryCountryCode: isSecureCore ? "IS" : exitCountry,
                exitCountryCode: exitCountry,
                tier: 0,
                score: 1,
                status: 1,
                feature: isSecureCore ? .secureCore : .zero,
                city: nil,
                state: nil,
                hostCountry: nil,
                translatedCity: nil,
                latitude: 0,
                longitude: 0,
                gatewayName: gatewayName
            )
            let endpoint = ServerEndpoint(
                id: "preview-endpoint",
                entryIp: "10.0.0.1",
                exitIp: "10.0.0.2",
                domain: "preview.protonvpn.ch",
                status: 1,
                label: nil,
                x25519PublicKey: nil,
                protocolEntries: nil
            )
            return Server(logical: logical, endpoint: endpoint)
        }
    }
#endif
