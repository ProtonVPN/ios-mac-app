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

public enum ConnectionProtocol: Codable, Equatable {
    case vpnProtocol(VpnProtocol)
    case smartProtocol

    private enum Keys: CodingKey {
        case smartProtocol
        case vpnProtocol
    }

    public var vpnProtocol: VpnProtocol? {
        guard case let .vpnProtocol(vpnProtocol) = self else {
            return nil
        }
        return vpnProtocol
    }

    public var requiresSystemExtension: Bool {
        guard self != .smartProtocol else {
            return true
        }
        return vpnProtocol?.requiresSystemExtension == true
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        if let vpnProtocol = try container.decodeIfPresent(VpnProtocol.self, forKey: .vpnProtocol) {
            self = .vpnProtocol(vpnProtocol)
        } else {
            self = .smartProtocol
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .smartProtocol:
            try container.encode(true, forKey: .smartProtocol)
        case let .vpnProtocol(vpnProtocol):
            try container.encode(vpnProtocol, forKey: .vpnProtocol)
        }
    }
}

public struct ConnectionRequest: Codable {
    public let serverType: ServerType
    public let connectionType: ConnectionRequestType
    public let connectionProtocol: ConnectionProtocol
    public let netShieldType: NetShieldType
    public let natType: NATType
    public let profileId: String?

    public init(serverType: ServerType, connectionType: ConnectionRequestType, connectionProtocol: ConnectionProtocol, netShieldType: NetShieldType, natType: NATType, profileId: String?) {
        self.serverType = serverType
        self.connectionType = connectionType
        self.connectionProtocol = connectionProtocol
        self.netShieldType = netShieldType
        self.profileId = profileId
        self.natType = natType
    }
    
    public func withChanged(netShieldType: NetShieldType) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: self.connectionProtocol, netShieldType: netShieldType, natType: self.natType, profileId: self.profileId)
    }

    public func withChanged(natType: NATType) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: self.connectionProtocol, netShieldType: self.netShieldType, natType: natType, profileId: self.profileId)
    }

    public func withChanged(connectionProtocol: ConnectionProtocol) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: connectionProtocol, netShieldType: self.netShieldType, natType: self.natType, profileId: self.profileId)
    }

    private enum Keys: CodingKey {
        case serverType
        case connectionType
        case connectionProtocol
        case netShieldType
        case profileId
        case vpnProtocol
        case natType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        serverType = try container.decode(ServerType.self, forKey: .serverType)
        connectionType = try container.decode(ConnectionRequestType.self, forKey: .connectionType)
        netShieldType = try container.decode(NetShieldType.self, forKey: .netShieldType)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)

        // compatiblity with previous format
        if let vpnProtocol = try container.decodeIfPresent(VpnProtocol.self, forKey: .vpnProtocol) {
            connectionProtocol = .vpnProtocol(vpnProtocol)
        } else {
            connectionProtocol = try container.decode(ConnectionProtocol.self, forKey: .connectionProtocol)
        }
        if let natTypeValue = try container.decodeIfPresent(NATType.self, forKey: .natType) {
            natType = natTypeValue
        } else {
            natType = .default
        }
    }
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
        return lhs.serverType == rhs.serverType && lhs.connectionType == rhs.connectionType && lhs.connectionProtocol == rhs.connectionProtocol
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
