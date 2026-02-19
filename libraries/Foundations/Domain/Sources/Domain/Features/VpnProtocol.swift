//
//  Created on 11.01.23.
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

public enum WireGuardTransport: String, Codable, Equatable, CaseIterable, Sendable {
    case udp
    case tcp
    case tls

    public static let defaultValue: Self = .udp
}

public enum VpnProtocol: Equatable, Hashable, CaseIterable, Sendable, Codable {
    public static let allCases: [VpnProtocol] = [.ike]
        + WireGuardTransport.allCases.map(Self.wireGuard)

    public enum CodingError: Swift.Error {
        case unknownValue(Int)
        case deprecatedValue(Int)
    }

    #if os(macOS)
        /// Set of protocols that are deprecated on macOS
        public static let deprecatedProtocols: [VpnProtocol] = []
    #else
        /// Set of protocols that are deprecated on iOS and tvOS
        public static let deprecatedProtocols: [VpnProtocol] = [.ike]
    #endif

    public var isDeprecated: Bool { Self.deprecatedProtocols.contains(self) }

    case ike
    case wireGuard(WireGuardTransport)

    enum Key: CodingKey {
        case rawValue
        case transportProtocol
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)

        switch rawValue {
        case 0:
            self = .ike
        case 1:
            // Historically, 1 represented openVPN
            throw CodingError.deprecatedValue(1)
        case 2:
            let transportProtocol = (try? container.decode(WireGuardTransport.self, forKey: .transportProtocol)) ?? .udp
            self = .wireGuard(transportProtocol)
        default:
            throw CodingError.unknownValue(rawValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)

        switch self {
        case .ike:
            try container.encode(0, forKey: .rawValue)
        case let .wireGuard(transportProtocol):
            try container.encode(2, forKey: .rawValue)
            try container.encode(transportProtocol, forKey: .transportProtocol)
        }
    }
}

// MARK: - Default values

public extension VpnProtocol {
    #if os(iOS)
        static let defaultValue: Self = .wireGuard(.udp)
    #else
        static let defaultValue: Self = .ike
    #endif

    private static let uiOrder: [VpnProtocol: Int] = [
        .wireGuard(.udp): 1,
        .wireGuard(.tcp): 2,
        .ike: 3,
        .wireGuard(.tls): 4,
    ]

    static func uiSort(lhs: VpnProtocol, rhs: VpnProtocol) -> Bool {
        uiOrder[lhs] ?? 0 < uiOrder[rhs] ?? 0
    }
}

// MARK: - API description

public extension VpnProtocol {
    var apiDescription: String {
        switch self {
        case .ike:
            "IKEv2"
        case let .wireGuard(transport):
            "WireGuard" + transport.rawValue.uppercased()
        }
    }

    init?(apiDescription: String) {
        switch apiDescription {
        case "IKEv2":
            self = .ike
        case "WireGuardUDP":
            self = .wireGuard(.udp)
        case "WireGuardTCP":
            self = .wireGuard(.tcp)
        case "WireGuardTLS":
            self = .wireGuard(.tls)
        default:
            return nil
        }
    }
}
