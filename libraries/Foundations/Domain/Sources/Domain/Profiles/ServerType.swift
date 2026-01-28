//
//  Created on 28/01/2026 by Chris Janusiewicz.
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

import Foundation

public enum ServerType: Int, Codable, CustomStringConvertible {
    case standard = 0
    case secureCore = 1
    case p2p = 2
    case tor = 3
    case unspecified = 4

    public init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .standard
        case 1:
            self = .secureCore
        case 2:
            self = .p2p
        case 3:
            self = .tor
        default:
            self = .unspecified
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case serverType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .serverType)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .serverType)
    }

    public var description: String {
        switch self {
        case .standard:
            "Standard"
        case .secureCore:
            "Secure Core"
        case .p2p:
            "P2P"
        case .tor:
            "Tor"
        case .unspecified:
            "Unspecified"
        }
    }
}
