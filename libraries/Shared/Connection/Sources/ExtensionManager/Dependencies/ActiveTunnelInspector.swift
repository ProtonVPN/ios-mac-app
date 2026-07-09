//
//  Created on 26/05/2026 by Max Kupetskyi.
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
import DependenciesMacros
import NetworkExtension

#if os(macOS)
    /// Read-only view onto the currently-loaded VPN tunnel configurations, intended for cross-user-tunnel
    /// detection on app launch / login.
    ///
    /// IKE tunnels embed the user's keychain name in their `NEVPNProtocolIKEv2.username` (set by
    /// `WireguardConfigurator.ikeConfiguration`)
    @DependencyClient
    public struct ActiveTunnelInspector: Sendable {
        /// Returns the base username (with the feature/endpoint suffix stripped) embedded in the
        /// currently-active IKE tunnel's NEVPNProtocolIKEv2 configuration. Returns `nil` when:
        ///   * No IKE manager is loaded
        ///   * The IKE manager exists but the session is `.invalid` or `.disconnected` (so it isn't
        ///     the active tunnel)
        ///   * The active config has no username for any reason
        ///
        /// `AppSessionManager.resolveActiveSession` compares the returned value with
        /// `vpnKeychain.fetch().name` to detect tunnels left running by a different signed-in user.
        public var activeIKEBaseUsername: @Sendable () async -> String?
    }

    extension ActiveTunnelInspector: DependencyKey, TestDependencyKey {
        public static let liveValue: Self = .init(
            activeIKEBaseUsername: {
                @Dependency(\.vpnManagerRepository) var vpnManagerRepository
                guard let managers = try? await vpnManagerRepository.managers(),
                      let ikeManager = managers[.ike] else {
                    return nil
                }
                switch ikeManager.session.status {
                case .connecting, .connected, .reasserting, .disconnecting:
                    break
                case .invalid, .disconnected:
                    return nil
                @unknown default:
                    return nil
                }
                guard let username = ikeManager.protocolConfiguration?.username else {
                    return nil
                }
                return String(username.prefix { $0 != IkeUsernameComponent.concatChar })
            }
        )

        public static let testValue: Self = .init(activeIKEBaseUsername: { nil })
    }

    public extension DependencyValues {
        var activeTunnelInspector: ActiveTunnelInspector {
            get { self[ActiveTunnelInspector.self] }
            set { self[ActiveTunnelInspector.self] = newValue }
        }
    }
#endif
