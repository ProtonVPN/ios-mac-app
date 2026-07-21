//
//  Created on 07/07/2026.
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

private import Network
private import NetworkingErgonomics

public enum DNSTransport: Hashable {
    case classic
    case https(path: String?)
    case tls
}

public struct HermesResolver: Hashable {
    public enum Error: Swift.Error {
        case invalidIPAddress
    }

    public static let storagePathComponent: String = "hermes.json"

    public let location: String

    public init(ipAddress: String) throws(Error) {
        guard HermesResolverLocationValidator.isValidIPv4(ipAddress) != nil else {
            throw .invalidIPAddress
        }
        self.location = ipAddress
    }
}

// We have two entities because of legacy reasons
// This one was used in WireGuardKit-Apple
// Merging HermesResolver and DNSResolver would break Codable conformances so let's keep both
public struct DNSResolver {
    public let transport: DNSTransport
    private let address: any IPAddress
}

public extension DNSResolver {
    static let proton: Self = .init(from: .proton)!
}

// MARK: - Conformances and other helpers

extension HermesResolver: Identifiable {
    public var id: String {
        location
    }
}

extension HermesResolver: Codable {}

extension DNSTransport {
    var sortOrder: Int {
        switch self {
        case .https: 0
        case .tls: 1
        case .classic: 2
        }
    }

    static func transport(from url: URL) -> DNSTransport {
        switch url.scheme {
        case "https":
            let path = url.path()
            return .https(path: path.isEmpty ? nil : path)
        case "tls":
            return .tls
        default:
            return .classic
        }
    }
}

extension DNSResolver: Equatable {
    public static func == (lhs: DNSResolver, rhs: DNSResolver) -> Bool {
        lhs.address.rawValue == rhs.address.rawValue && lhs.transport == rhs.transport
    }
}

extension DNSResolver: Comparable {
    public static func < (lhs: DNSResolver, rhs: DNSResolver) -> Bool {
        lhs.transport.sortOrder < rhs.transport.sortOrder
    }
}

public extension DNSResolver {
    var stringRepresentation: String {
        switch transport {
        case let .https(path?):
            "https://\(address)\(path)"
        case .https(nil):
            "https://\(address)"
        case .tls, .classic:
            "\(address)"
        }
    }

    init?(from hermesResolver: HermesResolver) {
        self.init(from: hermesResolver.location)
    }

    /// Parses a resolver location string (a bare IP, or a `tls://`/`https://` URL) as sent over IPC.
    init?(from location: String) {
        guard let url = URL(string: location) else {
            return nil
        }

        let transport = DNSTransport.transport(from: url)

        let host: String = url.host() ?? location

        if let addr = IPv4Address(host) {
            self.address = addr
            self.transport = transport
        } else if let addr = IPv6Address(host) {
            self.address = addr
            self.transport = transport
        } else {
            return nil
        }
    }
}
