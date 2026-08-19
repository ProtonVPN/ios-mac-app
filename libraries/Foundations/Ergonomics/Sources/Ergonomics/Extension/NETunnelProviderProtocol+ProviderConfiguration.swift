//
//  Created on 2022-09-30.
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
import NetworkExtension

public extension NETunnelProviderProtocol {
    fileprivate enum CustomKeys: String {
        case connectedLogicalIdKey = "PVPNLogicalID"
        case connectedServerIpIdKey = "PVPNServerIpID"
        case wgProtocolKey = "wg-protocol"
        case pcapFileKey = "PVPNPcapFile"
    }

    private func ensureProviderConfig() {
        guard providerConfiguration == nil else { return }

        providerConfiguration = [:]
    }

    var connectedLogicalId: String? {
        get {
            providerConfiguration?[.connectedLogicalIdKey] as? String ??
                providerConfiguration?["PVPNServerID"] as? String // old name for the key
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.connectedLogicalIdKey] = newValue
        }
    }

    var connectedServerIpId: String? {
        get {
            providerConfiguration?[.connectedServerIpIdKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.connectedServerIpIdKey] = newValue
        }
    }

    var wgProtocol: String? {
        get {
            providerConfiguration?[.wgProtocolKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.wgProtocolKey] = newValue
        }
    }

    /// The file the app wants ProTUN to write a packet capture into, or `nil` when it wants no capture.
    var pcapCaptureFileURL: URL? {
        get {
            (providerConfiguration?[.pcapFileKey] as? String).flatMap(URL.init(string:))
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.pcapFileKey] = newValue?.absoluteString
        }
    }
}

private extension [String: Any] {
    subscript(_ customKey: NETunnelProviderProtocol.CustomKeys) -> Any? {
        get {
            self[customKey.rawValue]
        }
        set {
            self[customKey.rawValue] = newValue
        }
    }
}
