//
//  Created on 18/12/2023.
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
import GRDB

struct Endpoint: Codable {
    let logicalId: String
    let id: String
    let entryIp: String?
    let exitIp: String
    let domain: String
    let status: Int
    let label: String?
    let x25519PublicKey: String?

    /// Bit mask of the protocols this endpoint has an address for, cached so that queries can filter on
    /// protocol support without reading the per-protocol entries. `ServerEndpoint.supportedProtocols`
    /// computes it.
    let protocolMask: Int
}
