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

import Ergonomics
import Foundation

public struct WireguardConfig: Codable, Equatable, Sendable {
    public let defaultUdpPorts: [Int]
    public let defaultTcpPorts: [Int]
    public let defaultTlsPorts: [Int]

    // This is an optional array to be more *lenient* regarding Decodable conformance
    public let dnsServers: [String]?

    public var address: String {
        "10.2.0.2/32"
    }

    public var allowedIPs: String {
        "0.0.0.0/0"
    }

    public var persistentKeepalive: Int? { // seconds
        25
    }

    public init(
        defaultUdpPorts: [Int]? = nil,
        defaultTcpPorts: [Int]? = nil,
        defaultTlsPorts: [Int]? = nil,
        dns: [String] = ["10.2.0.1"]
    ) {
        self.defaultUdpPorts = defaultUdpPorts.unwrappedOr(defaultValue: [51820])
        self.defaultTcpPorts = defaultTcpPorts.unwrappedOr(defaultValue: [443])
        self.defaultTlsPorts = defaultTlsPorts.unwrappedOr(defaultValue: [443])
        self.dnsServers = dns
    }

    public init() {
        self.init(defaultUdpPorts: nil, defaultTcpPorts: nil, defaultTlsPorts: nil)
    }
}

public struct StoredWireguardConfig: Codable {
    /// Add a case here if you change `StoredWireguardConfig` in a way old data cannot satisfy, and
    /// teach `decodeLegacyKeychainData` how to read the new layout. Adding optional fields instead
    /// keeps older stored data readable and needs no new version.
    public enum Version: Int {
        case v1 = 1
    }

    public let wireguardConfig: WireguardConfig

    public let clientPrivateKey: String?
    public let serverPublicKey: String?
    public let entryServerAddress: String
    public let ports: [Int]

    public let timestamp: Date

    public init(
        wireguardConfig: WireguardConfig,
        clientPrivateKey: String?,
        serverPublicKey: String?,
        entryServerAddress: String,
        ports: [Int],
        timestamp: Date
    ) {
        precondition(!ports.isEmpty, "Ports should not be empty")
        self.wireguardConfig = wireguardConfig
        self.clientPrivateKey = clientPrivateKey
        self.serverPublicKey = serverPublicKey
        self.entryServerAddress = entryServerAddress
        self.ports = ports
        self.timestamp = timestamp
    }
}

public extension StoredWireguardConfig {
    enum LegacyKeychainDecodingError: Error {
        case noData
        case unsupportedVersion(Int)
        case decodingFailed(any Error)
    }

    /// Decode the layout written to the tunnel keychain: a single version byte followed by
    /// JSON-encoded `StoredWireguardConfig`.
    static func decodeLegacyKeychainData(
        _ data: Data
    ) throws(LegacyKeychainDecodingError) -> StoredWireguardConfig {
        guard let firstByte = data.first else {
            throw .noData
        }
        guard let version = Version(rawValue: Int(firstByte)),
              case .v1 = version else {
            throw .unsupportedVersion(Int(firstByte))
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data.dropFirst())
        } catch {
            throw .decodingFailed(error)
        }
    }
}
