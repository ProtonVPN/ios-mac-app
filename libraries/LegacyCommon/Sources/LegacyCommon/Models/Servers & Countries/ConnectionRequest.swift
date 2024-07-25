//
//  ConnectionRequest.swift
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

import Domain
import Strings

import VPNShared
import VPNAppCore

extension ConnectionProtocol: CustomStringConvertible {

    public static let deprecatedProtocols: [Self] = VpnProtocol.deprecatedProtocols.map(vpnProtocol)

    public var isDeprecated: Bool {
        switch self {
        case .smartProtocol:
            return false
        case .vpnProtocol(let vpnProtocol):
            return vpnProtocol.isDeprecated
        }
    }

    /// Returns an array of all supported protocols on the current platform.
    /// - Parameter wireguardTLS: Whether WireGuard TLS feature flag enabled. If false, the protocol list will not
    /// include WireGuard TCP and TLS.
    public static func availableProtocols(wireguardTLSEnabled: Bool) -> [Self] {
        return allCases
            .removing([.vpnProtocol(.wireGuard(.tcp)), .vpnProtocol(.wireGuard(.tls))], if: !wireguardTLSEnabled)
            .removing(deprecatedProtocols)
    }

    public var description: String {
        return localizedString
    }

    public var localizedString: String {
        switch self {
        case let .vpnProtocol(vpnProtocol):
            return vpnProtocol.localizedString
        case .smartProtocol:
            return Localizable.smartTitle
        }
    }

    public static func uiSort(lhs: Self, rhs: Self) -> Bool {
        guard let lhsProtocol = lhs.vpnProtocol, let rhsProtocol = rhs.vpnProtocol else {
            return lhs == .smartProtocol && rhs != .smartProtocol // smart protocol gets sorted first
        }

        return VpnProtocol.uiSort(lhs: lhsProtocol, rhs: rhsProtocol)
    }
}

public struct ConnectionRequest: Identifiable {
    public let id = UUID()
    public let serverType: ServerType
    public let connectionType: ConnectionRequestType
    public let connectionProtocol: ConnectionProtocol
    public let netShieldType: NetShieldType
    public let natType: NATType
    public let safeMode: Bool?
    public let profileId: String?
    public let profileName: String?
    public let trigger: ConnectionDimensions.VPNTrigger?

    public init(serverType: ServerType, connectionType: ConnectionRequestType, connectionProtocol: ConnectionProtocol, netShieldType: NetShieldType, natType: NATType, safeMode: Bool?, profileId: String?, profileName: String?, trigger: ConnectionDimensions.VPNTrigger?) {
        self.serverType = serverType
        self.connectionType = connectionType
        self.connectionProtocol = connectionProtocol
        self.netShieldType = netShieldType
        self.profileId = profileId
        self.profileName = profileName
        self.natType = natType
        self.safeMode = safeMode
        self.trigger = trigger
    }
    
    public func withChanged(netShieldType: NetShieldType) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: self.connectionProtocol, netShieldType: netShieldType, natType: self.natType, safeMode: self.safeMode, profileId: self.profileId, profileName: self.profileName, trigger: self.trigger)
    }

    public func withChanged(natType: NATType) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: self.connectionProtocol, netShieldType: self.netShieldType, natType: natType, safeMode: self.safeMode, profileId: self.profileId, profileName: self.profileName, trigger: self.trigger)
    }

    public func withChanged(safeMode: Bool) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: self.connectionProtocol, netShieldType: self.netShieldType, natType: self.natType, safeMode: safeMode, profileId: self.profileId, profileName: self.profileName, trigger: self.trigger)
    }

    public func withChanged(connectionProtocol: ConnectionProtocol) -> ConnectionRequest {
        return ConnectionRequest(serverType: self.serverType, connectionType: self.connectionType, connectionProtocol: connectionProtocol, netShieldType: self.netShieldType, natType: self.natType, safeMode: self.safeMode, profileId: self.profileId, profileName: self.profileName, trigger: self.trigger)
    }

    private enum Keys: CodingKey {
        case serverType
        case connectionType
        case connectionProtocol
        case netShieldType
        case profileId
        case profileName
        case vpnProtocol
        case natType
        case safeMode
        case trigger
    }
}

extension ConnectionRequest: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        serverType = try container.decode(ServerType.self, forKey: .serverType)
        connectionType = try container.decode(ConnectionRequestType.self, forKey: .connectionType)
        netShieldType = try container.decode(NetShieldType.self, forKey: .netShieldType)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName)

        // compatibility with previous format
        if let vpnProtocol = try container.decodeIfPresent(VpnProtocol.self, forKey: .vpnProtocol) {
            connectionProtocol = .vpnProtocol(vpnProtocol)
        } else {
            connectionProtocol = try container.decode(ConnectionProtocol.self, forKey: .connectionProtocol)
        }

        // compatibility with previous format
        if let natTypeValue = try container.decodeIfPresent(NATType.self, forKey: .natType) {
            natType = natTypeValue
        } else {
            natType = .default
        }

        safeMode = try container.decodeIfPresent(Bool.self, forKey: .safeMode)
        trigger = try container.decodeIfPresent(ConnectionDimensions.VPNTrigger.self, forKey: .trigger)
    }
}

public enum ConnectionRequestType {
    
    case fastest
    case random
    case country(String, CountryConnectionRequestType)
    case city(country: String, city: String)
}

public enum CountryConnectionRequestType {
    
    case fastest
    case random
    case server(ServerModel)
}

extension ConnectionRequestType: Codable {
    
    private enum Key: CodingKey {
        case rawValue
        case countryCode
        case countryConnectionRequestType
        case city
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
        case 3:
            let countryCode = try container.decode(String.self, forKey: .countryCode)
            let city = try container.decode(String.self, forKey: .city)
            self = .city(country: countryCode, city: city)
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
        case let .country(countryCode, countryConnectionRequestType):
            try container.encode(2, forKey: .rawValue)
            try container.encode(countryCode, forKey: .countryCode)
            try container.encode(countryConnectionRequestType, forKey: .countryConnectionRequestType)
        case let .city(country: countryCode, city: city):
            try container.encode(3, forKey: .rawValue)
            try container.encode(countryCode, forKey: .countryCode)
            try container.encode(city, forKey: .city)
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
