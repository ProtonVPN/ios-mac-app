//
//  ServerType.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings

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

    public static let humanReadableCases: [Self] = [.standard, .secureCore, .p2p, .tor]

    public var localizedString: String {
        switch self {
        case .standard:
            return Localizable.standard
        case .secureCore:
            return Localizable.secureCore
        case .p2p:
            return Localizable.p2p
        case .tor:
            return Localizable.tor
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
        self.init(rawValue: Int(data[0]))
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
    
    // MARK: - Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CoderKey.self)
        let rawValue = try container.decode(Int.self, forKey: .serverType)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKey.self)
        try container.encode(self.rawValue, forKey: .serverType)
    }
}
