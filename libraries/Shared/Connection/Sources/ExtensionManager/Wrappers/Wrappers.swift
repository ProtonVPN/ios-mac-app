//
//  Created on 29/05/2024.
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

import Foundation
// Several types are used directly because we don't need to wrap them for stubbing
import class NetworkExtension.NEOnDemandRule
import class NetworkExtension.NETunnelProviderProtocol
import enum NetworkExtension.NEVPNStatus

import Dependencies

import protocol ExtensionIPC.ProviderMessageSender

/// Wraps `NETunnelProviderSession`.
public protocol VPNSession: ProviderMessageSender {
    var status: NEVPNStatus { get }
    var connectedDate: Date? { get }
    func fetchLastDisconnectError() async throws -> Error?

    func startTunnel() throws
    func stopTunnel()
    func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws
}

/// Wraps `NETunnelProviderManager`
public protocol TunnelProviderManager {
    func loadFromPreferences() async throws
    func saveToPreferences() async throws
    func removeFromPreferences() async throws

    var session: VPNSession { get }

    var vpnProtocolConfiguration: NETunnelProviderProtocol? { get set }
    var onDemandRules: [NEOnDemandRule]? { get set }
    var isOnDemandEnabled: Bool { get set }
    var isEnabled: Bool { get set }
}
