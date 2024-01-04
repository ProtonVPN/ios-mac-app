//
//  Created on 2022-03-29.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation

import Domain
import VPNAppCore

public protocol VpnConnectionInterceptDelegate: AnyObject {
    var vpnConnectionInterceptPolicies: [VpnConnectionInterceptPolicyItem] { get }
}

/// A policy item for "intercepting" an attempted VPN connection in `VpnGateway`. These can be used
/// to prevent connections that are known to cause instability or other bugs when combined with
/// certain features, when used on certain platforms, or when configured on certain OS versions.
public protocol VpnConnectionInterceptPolicyItem {
    func shouldIntercept(_ connectionProtocol: ConnectionProtocol, isKillSwitchOn: Bool, completion: @escaping (VpnConnectionInterceptResult) -> Void)
}

/// The result of the decision to intercept. Each policy item can decide either to allow the
/// connection, in which case the connection flow proceeds normally, or can decide to modify some
/// aspect of the connection configuration (usually after displaying a dialog to the user giving
/// them an opportunity to decide which aspect of the connection they want to change).
public enum VpnConnectionInterceptResult {
    /// Aspects of the connection that we want to change before proceeding with the connnection.
    public struct InterceptParameters {
        /// The "new" protocol (can be the same as the old one, if other parameters are changing)
        public let newProtocol: ConnectionProtocol
        /// Disable WireGuard when connecting with Smart Protocol.
        public let smartProtocolWithoutWireGuard: Bool
        /// Whether to connect with Kill Switch enabled.
        public let newKillSwitch: Bool

        public init(newProtocol: ConnectionProtocol, smartProtocolWithoutWireGuard: Bool, newKillSwitch: Bool) {
            self.newProtocol = newProtocol
            self.smartProtocolWithoutWireGuard = smartProtocolWithoutWireGuard
            self.newKillSwitch = newKillSwitch
        }
    }

    /// Intercept the connection, changing the connection settings with the given parameters.
    case intercept(InterceptParameters)
    /// Allow the connection to proceed.
    case allow
}
