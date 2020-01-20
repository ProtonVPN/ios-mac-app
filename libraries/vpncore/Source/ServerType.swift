//
//  ServerType.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public enum ServerType: Codable {
    
    case standard
    case secureCore
    case p2p
    case tor
    case unspecified
    
    public var description: String {
        switch self {
        case .standard:
            return "Standard"
        case .secureCore:
            return "Secure Core"
        case .p2p:
            return "P2P"
        case .tor:
            return "Tor"
        case .unspecified:
            return "Unspecified"
        }
    }
    
    // MARK: - NSCoding
    private enum CoderKey: String, CodingKey {
        case serverType = "serverType"
    }
    
    public init(coder aDecoder: NSCoder) {
        let data = aDecoder.decodeObject(forKey: CoderKey.serverType.rawValue) as! Data
        switch data[0] {
        case 0:
            self = .standard
        case 1:
            self = .secureCore
        case 2:
            self = .p2p
        case 3:
            self = .tor
        default: // case 4:
            self = .unspecified
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        switch self {
        case .standard:
            data[0] = 0
        case .secureCore:
            data[0] = 1
        case .p2p:
            data[0] = 2
        case .tor:
            data[0] = 3
        case .unspecified:
            data[0] = 4
        }
        aCoder.encode(data, forKey: CoderKey.serverType.rawValue)
    }
    
    // MARK: - Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CoderKey.self)
        let rawValue = try container.decode(Int.self, forKey: .serverType)
        switch rawValue {
        case 0:
            self = .standard
        case 1:
            self = .secureCore
        case 2:
            self = .p2p
        case 3:
            self = .tor
        default: // case 4:
            self = .unspecified
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKey.self)
        switch self {
        case .standard:
            try container.encode(0, forKey: .serverType)
        case .secureCore:
            try container.encode(1, forKey: .serverType)
        case .p2p:
            try container.encode(2, forKey: .serverType)
        case .tor:
            try container.encode(3, forKey: .serverType)
        case .unspecified:
            try container.encode(4, forKey: .serverType)
        }
    }
}
