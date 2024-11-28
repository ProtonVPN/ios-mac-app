//
//  Created on 28/11/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros

@DependencyClient
package struct BundleIDClient: Sendable {
    package internal(set) var bundleIdentifierForTarget: @Sendable () -> String = { "<invalid>" }
}

extension DependencyValues {
    package var bundleIDClient: BundleIDClient {
        get { self[BundleIDClient.self] }
        set { self[BundleIDClient.self] = newValue }
    }
}

extension BundleIDClient: DependencyKey {
    package static let liveValue = BundleIDClient {
        #if os(iOS)
        return "ch.protonmail.vpn.WireGuardiOS-Extension"
        #elseif os(macOS)
        return "ch.protonvpn.mac.WireGuard-Extension"
        #elseif os(tvOS)
        return "ch.protonmail.vpn.WireGuard-tvOS"
        #else
        fatalError("Unsupported platform")
        #endif
    }
}
