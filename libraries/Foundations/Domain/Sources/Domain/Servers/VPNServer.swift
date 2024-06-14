//
//  Created on 2023-07-05.
//
//  Copyright (c) 2023 Proton AG
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
import CoreLocation

/// This is a struct version of `ServerModel` object from `LegacyCommon`.
///
/// Functions mapping `VpnServer` to legacy `ServerModel` DTO and vice versa are available in `LegacyCommon`.
///
/// The plan is to get rid of `ServerModel` whenever possible and move to using this struct only.
public struct VPNServer: Codable, Equatable, Identifiable {
    public let logical: Logical
    public let endpoints: [ServerEndpoint]

    public var id: String { logical.id }

    public init(logical: Logical, endpoints: [ServerEndpoint]) {
        self.logical = logical
        self.endpoints = endpoints
    }

    public var supportedProtocols: ProtocolSupport {
        return endpoints.reduce(.zero) { $0.union($1.supportedProtocols) }
    }
}

/// A pairing of a logical and a single server, used to reduce ambiguity when choosing what server to connect to
public struct Server: Equatable, Sendable {
    public let logical: Logical
    public let endpoint: ServerEndpoint

    public init(logical: Logical, endpoint: ServerEndpoint) {
        self.logical = logical
        self.endpoint = endpoint
    }
}
