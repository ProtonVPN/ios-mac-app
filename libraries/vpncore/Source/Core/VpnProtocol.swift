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
    public enum AuthenticationType {
        case credentials
        case certificate
    }
    
    // swiftlint:disable nesting
    public enum TransportProtocol: String, Codable {
        
        case tcp = "tcp"
        case udp = "udp"
        case undefined = "undefined"
        
        private struct CoderKey {
            static let transportProtocol = "transportProtocol"
        }
        
        public init(coder aDecoder: NSCoder) {
            guard let data = aDecoder.decodeObject(forKey: CoderKey.transportProtocol) as? Data else {
                self = .undefined
                return
            }
            switch data[0] {
            case 0:
                self = .tcp
            case 1:
                self = .udp
            default:
                self = .undefined
            }
        }
        
        public func encode(with aCoder: NSCoder) {
            var data = Data(count: 1)
            switch self {
            case .tcp:
                data[0] = 0
            case .udp:
                data[0] = 1
            case .undefined:
                data[0] = 2
            }
            aCoder.encode(data, forKey: CoderKey.transportProtocol)
        }
    }
    // swiftlint:enable nesting
    
    case ike
    case openVpn(TransportProtocol)
    case wireGuard
    
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
            case .undefined:
                break
            }
        case .wireGuard:
            string = LocalizedString.wireguard
        }
        
        return string
    }
    
    public var isIke: Bool {
        if case .ike = self {
            return true
        } else {
            return false
        }
    }
    
    public var isOpenVpn: Bool {
        if case .openVpn = self {
            return true
        } else {
            return false
        }
    }
    
    public func isOpenVpn(_ transportProtocol: TransportProtocol) -> Bool {
        if case .openVpn(let transport) = self {
            return transportProtocol == transport
        } else {
            return false
        }
    }
    
    public var isWireGuard: Bool {
        if case .wireGuard = self {
            return true
        } else {
            return false
        }
    }

    public var authenticationType: AuthenticationType {
        switch self {
        case .ike: return .credentials
        case .openVpn: return .credentials
        case .wireGuard: return .certificate
        }
    }

    public var transportProtocol: TransportProtocol {
        switch self {
        case .ike:
            return .undefined
        case .openVpn(let transportProtocol):
            return transportProtocol
        case .wireGuard:
            return .undefined
        }
    }
}

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
            let transportProtocol = try container.decode(TransportProtocol.self, forKey: .transportProtocol)
            self = .openVpn(transportProtocol)
        case 2:
            self = .wireGuard
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
        case .wireGuard:
            try container.encode(2, forKey: .rawValue)
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
            self = .openVpn(TransportProtocol(coder: aDecoder))
        case 2:
            self = .wireGuard
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

extension VpnProtocol: Equatable {}
