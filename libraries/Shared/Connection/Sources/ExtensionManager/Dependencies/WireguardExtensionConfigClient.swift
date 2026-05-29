//
//  Created on 27/05/2026 by Max Kupetskyi.
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

import CoreConnection
import Dependencies
import DependenciesMacros
import Domain
import Foundation

#if os(macOS)
    /// Pushes the WireGuard `configData` blob into the macOS WireGuard system extension via XPC.
    @DependencyClient
    public struct WireguardExtensionConfigClient: Sendable {
        /// Pushes `configData` to the extension. Returns `true` on success, `false` if the XPC
        /// channel couldn't be established or the extension reported failure.
        public var pushConfig: @Sendable (_ configData: Data) async -> Bool = { _ in false }
    }

    extension WireguardExtensionConfigClient: TestDependencyKey {
        /// Tests default to success so existing tests that don't care about the XPC path keep
        /// passing. Tests that exercise the failure path should override with a closure returning
        /// `false`.
        public static let testValue = WireguardExtensionConfigClient(
            pushConfig: { _ in true }
        )
    }

    extension WireguardExtensionConfigClient: DependencyKey {
        public static let liveValue = WireguardExtensionConfigClient(
            pushConfig: { configData in
                let xpcUser = XPCServiceUser(
                    withExtension: "\(DomainConstants.appIdentifierPrefix)group.\(DomainConstants.NetworkExtensions.wireguard)",
                    logger: { log.debug("\($0)", category: .protocol) }
                )
                return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                    xpcUser.setConfigData(configData) { success in
                        continuation.resume(returning: success)
                    }
                }
            }
        )
    }

    public extension DependencyValues {
        var wireguardExtensionConfigClient: WireguardExtensionConfigClient {
            get { self[WireguardExtensionConfigClient.self] }
            set { self[WireguardExtensionConfigClient.self] = newValue }
        }
    }
#endif
