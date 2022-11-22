//
//  VpnProtocol.swift
//  ProtonVPN - Created on 13.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public enum VpnProtocol {
    case ike
    case openVpn(OpenVpnTransport)
    case wireGuard(WireGuardTransport)
}

public enum OpenVpnTransport: String, Codable {
    case tcp = "tcp"
    case udp = "udp"

    private static var defaultValue = OpenVpnTransport.tcp
}

public enum WireGuardTransport: String, Codable, Equatable {
    case udp = "udp"
    case tcp = "tcp"
    case tls = "tls"

    private static var defaultValue = WireGuardTransport.udp
}

// MARK: -

extension VpnProtocol { // Authentication

    public enum AuthenticationType {
        case credentials
        case certificate
    }

    public var authenticationType: AuthenticationType {
        switch self {
        case .ike: return .credentials
        case .openVpn: return .credentials
        case .wireGuard: return .certificate
        }
    }
}

extension VpnProtocol { // Text for UI
    public var localizedString: String {
        var string: String
        switch self {
        case .ike:
            string = LocalizedString.ikev2
        case .openVpn(let transportProtocol):
            string = LocalizedString.openvpn
            switch transportProtocol {
            case .tcp:
                string += " (\(LocalizedString.tcp))"
            case .udp:
                string += " (\(LocalizedString.udp))"
            }
        case .wireGuard(let transportProtocol):
            string = LocalizedString.wireguard
            switch transportProtocol {
            case .udp:
                string += "" // (\(LocalizedString.udp))
            case .tcp:
                string += " (\(LocalizedString.tcp))"
            case .tls:
                string = LocalizedString.wireguardTls
            }
        }

        return string
    }
}

extension VpnProtocol { // Order of vpn protocols in UI
    public static var uiOrder: [VpnProtocol: Int] = [
        .wireGuard(.udp): 1,
        .wireGuard(.tcp): 2,
        .openVpn(.udp): 3,
        .openVpn(.tcp): 4,
        .ike: 5,
        .wireGuard(.tls): 6,
    ]
}

// MARK: - Codable

extension VpnProtocol: Codable {
    
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
            let transportProtocol = try container.decode(OpenVpnTransport.self, forKey: .transportProtocol)
            self = .openVpn(transportProtocol)
        case 2:
            let transportProtocol = (try? container.decode(WireGuardTransport.self, forKey: .transportProtocol)) ?? .udp
            self = .wireGuard(transportProtocol)
        default:
            throw CodingError.unknownValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
        case .ike:
            try container.encode(0, forKey: .rawValue)
        case .openVpn(let transportProtocol):
            try container.encode(1, forKey: .rawValue)
            try container.encode(transportProtocol, forKey: .transportProtocol)
        case .wireGuard(let transportProtocol):
            try container.encode(2, forKey: .rawValue)
            try container.encode(transportProtocol, forKey: .transportProtocol)
        }
    }
}

// MARK: - NSCoding (used by Profile)

extension VpnProtocol {
    private struct CoderKey {
        static let vpnProtocol = "vpnProtocol"
        static let transportProtocol = "transportProtocol"
    }
    
    public init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: CoderKey.vpnProtocol) as? Data else {
            return nil
        }
        
        switch data[0] {
        case 1:
            self = .openVpn(OpenVpnTransport(coder: aDecoder))
        case 2:
            self = .wireGuard(WireGuardTransport(coder: aDecoder))
        default:
            self = .ike
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        switch self {
        case .ike:
            data[0] = 0
        case .openVpn(let transportProtocol):
            data[0] = 1
            transportProtocol.encode(with: aCoder)
        case .wireGuard:
            data[0] = 2
        }
        aCoder.encode(data, forKey: CoderKey.vpnProtocol)
    }
}

// MARK: API description
extension VpnProtocol {
    static let apiDescriptionsToProtocols: [String: VpnProtocol] = [
        "IKEv2": .ike,
        "OpenVPNUDP": .openVpn(.udp),
        "OpenVPNTCP": .openVpn(.tcp),
        "WireGuardUDP": .wireGuard(.udp),
        "WireGuardTCP": .wireGuard(.tcp),
        "WireGuardTLS": .wireGuard(.tls),
    ]

    static let protocolsToApiDescriptions: [VpnProtocol: String] = [
        .ike: "IKEv2",
        .openVpn(.udp): "OpenVPNUDP",
        .openVpn(.tcp): "OpenVPNTCP",
        .wireGuard(.udp): "WireGuardUDP",
        .wireGuard(.tcp): "WireGuardTCP",
        .wireGuard(.tls): "WireGuardTLS",
    ]
}

extension OpenVpnTransport {

    private struct CoderKey {
        static let transportProtocol = "transportProtocol"
    }

    public init(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: CoderKey.transportProtocol) as? Data else {
            self = .defaultValue
            return
        }
        switch data[0] {
        case 0:
            self = .tcp
        case 1:
            self = .udp
        default:
            self = .defaultValue
        }
    }

    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        switch self {
        case .tcp:
            data[0] = 0
        case .udp:
            data[0] = 1
        }
        aCoder.encode(data, forKey: CoderKey.transportProtocol)
    }
}

extension WireGuardTransport {

    private struct CoderKey {
        static let transportProtocol = "transportProtocol"
    }

    public init(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: CoderKey.transportProtocol) as? Data else {
            self = .defaultValue
            return
        }
        switch data[0] {
        case 0:
            self = .tcp
        case 1:
            self = .udp
        case 2:
            self = .tls
        default:
            self = .defaultValue
        }
    }

    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        switch self {
        case .tcp:
            data[0] = 0
        case .udp:
            data[0] = 1
        case .tls:
            data[0] = 2
        }
        aCoder.encode(data, forKey: CoderKey.transportProtocol)
    }
}

extension VpnProtocol: Equatable, Hashable {}

// MARK: - MacOS

#if os(macOS)
extension VpnProtocol {
    public var requiresSystemExtension: Bool {
        switch self {
        case .openVpn, .wireGuard:
            return true
        default:
            return false
        }
    }
}
#endif
