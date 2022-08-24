//
//  WireguardConfig.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

public struct WireguardConfig: Codable, Equatable {
    public let defaultUdpPorts: [Int]
    public let defaultTcpPorts: [Int]
    public let defaultTlsPorts: [Int]

    public var dns: String {
        return "10.2.0.1"
    }
    public var address: String {
        return "10.2.0.2/32"
    }
    public var allowedIPs: String {
        return "0.0.0.0/0"
    }

    init(defaultUdpPorts: [Int]? = nil, defaultTcpPorts: [Int]? = nil, defaultTlsPorts: [Int]? = nil) {
        self.defaultUdpPorts = defaultUdpPorts ?? [51820]
        self.defaultTcpPorts = defaultTcpPorts ?? [443]
        self.defaultTlsPorts = defaultTlsPorts ?? [443]
    }
}
