//
//  ConnectionRequest.swift
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

public struct ConnectionRequest: Codable {
    
    public let serverType: ServerType
    public let connectionType: ConnectionRequestType
}

public enum ConnectionRequestType {
    
    case fastest
    case random
    case country(String, CountryConnectionRequestType)
}

public enum CountryConnectionRequestType {
    
    case fastest
    case random
    case server(ServerModel)
}

// MARK: Codable conformance

extension ConnectionRequestType: Codable {
    
    private enum Key: CodingKey {
        case rawValue
        case countryCode
        case countryConnectionRequestType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .fastest
        case 1:
            self = .random
        case 2:
            let countryCode = try container.decode(String.self, forKey: .countryCode)
            let countryConnectionRequestType = try container.decode(CountryConnectionRequestType.self, forKey: .countryConnectionRequestType)
            self = .country(countryCode, countryConnectionRequestType)
        default:
            throw CodingError.unknownValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .fastest:
            try container.encode(0, forKey: .rawValue)
        case .random:
            try container.encode(1, forKey: .rawValue)
        case .country(let countryCode, let countryConnectionRequestType):
            try container.encode(2, forKey: .rawValue)
            try container.encode(countryCode, forKey: .countryCode)
            try container.encode(countryConnectionRequestType, forKey: .countryConnectionRequestType)
        }
    }
}

extension CountryConnectionRequestType: Codable {
    
    private enum Key: CodingKey {
        case rawValue
        case associatedValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .fastest
        case 1:
            self = .random
        case 2:
            let server = try container.decode(ServerModel.self, forKey: .associatedValue)
            self = .server(server)
        default:
            throw CodingError.unknownValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .fastest:
            try container.encode(0, forKey: .rawValue)
        case .random:
            try container.encode(1, forKey: .rawValue)
        case .server(let server):
            try container.encode(2, forKey: .rawValue)
            try container.encode(server, forKey: .associatedValue)
        }
    }
}

// MARK: Equatable conformance

extension ConnectionRequest: Equatable {
    
    public static func == (lhs: ConnectionRequest, rhs: ConnectionRequest) -> Bool {
        return lhs.serverType == rhs.serverType && lhs.connectionType == rhs.connectionType
    }
}

extension ConnectionRequestType: Equatable {
    
    public static func == (lhs: ConnectionRequestType, rhs: ConnectionRequestType) -> Bool {
        switch (lhs, rhs) {
        case (.fastest, .fastest):
            return true
        case (.random, .random):
            return true
        case (.country(let code1, let countryRequestType1), .country(let code2, let countryRequestType2)):
            return code1 == code2 && countryRequestType1 == countryRequestType2
        default:
            return false
        }
    }
}

extension CountryConnectionRequestType: Equatable {
    
    public static func == (lhs: CountryConnectionRequestType, rhs: CountryConnectionRequestType) -> Bool {
        switch (lhs, rhs) {
        case (.fastest, .fastest):
            return true
        case (.random, .random):
            return true
        case (.server(let server1), .server(let server2)):
            return server1 == server2
        default:
            return false
        }
    }
}
