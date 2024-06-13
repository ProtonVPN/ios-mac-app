//
//  Created on 03/06/2024.
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
import Network

import GoLibs

public struct ConnectionDetailsMessage: Sendable {
    let exitIp: IPAddress?
    let deviceIp: IPAddress?
    let deviceCountry: String?
}

extension ConnectionDetailsMessage {
    /// `LocalAgentConnectionDetails` is received with the `StatusUpdate` LocalAgent message.
    ///
    /// None of the fields of `LocalAgentConnectionDetails` are optional, so an empty string indicates a missing field.
    /// This wrapper struct makes sure that the IPs are valid before doing anything with them.
    init(details: LocalAgentConnectionDetails) {
        if !details.serverIpv4.isEmpty, let ipv4 = IPv4Address(details.serverIpv4) {
            self.exitIp = ipv4
        } else if !details.serverIpv6.isEmpty, let ipv6 = IPv6Address(details.serverIpv6) {
            self.exitIp = ipv6
        } else {
            self.exitIp = nil
        }

        if !details.deviceCountry.isEmpty {
            self.deviceCountry = details.deviceCountry
        } else {
            self.deviceCountry = nil
        }

        if !details.deviceIp.isEmpty {
            if let ipv4 = IPv4Address(details.deviceIp) {
                self.deviceIp = ipv4
            } else if let ipv6 = IPv6Address(details.deviceIp) {
                self.deviceIp = ipv6
            } else {
                self.deviceIp = nil
            }
        } else {
            self.deviceIp = nil
        }
    }
}
