//
//  VpnProtocol.swift
//  ProtonVPN - Created on 13.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

import Domain
import LocalFeatureFlags
import Strings

import VPNShared

extension VpnProtocol: DefaultableProperty {
    public init() {
        self = .defaultValue
    }
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
        case .openVpn:
            #if os(macOS)
            guard isEnabled(OpenVPNFeature.macCertificates) else {
                return .credentials
            }
            return .certificate
            #else
            guard isEnabled(OpenVPNFeature.iosCertificates) else {
                return .credentials
            }
            return .certificate
            #endif
        case .wireGuard: return .certificate
        }
    }
}

extension VpnProtocol { // Text for UI
    public var localizedString: String {
        var string: String
        switch self {
        case .ike:
            string = Localizable.ikev2
        case .openVpn(let transportProtocol):
            string = Localizable.openvpn
            switch transportProtocol {
            case .tcp:
                string += " (\(Localizable.tcp))"
            case .udp:
                string += " (\(Localizable.udp))"
            }
        case .wireGuard(let transportProtocol):
            string = Localizable.wireguard
            switch transportProtocol {
            case .udp:
                string += "" // (\(Localizable.udp))
            case .tcp:
                string += " (\(Localizable.tcp))"
            case .tls:
                string = Localizable.wireguardTls
            }
        }

        return string
    }

    private static var uiOrder: [VpnProtocol: Int] = [
        .wireGuard(.udp): 1,
        .wireGuard(.tcp): 2,
        .openVpn(.udp): 3,
        .openVpn(.tcp): 4,
        .ike: 5,
        .wireGuard(.tls): 6
    ]

    public static func uiSort(lhs: VpnProtocol, rhs: VpnProtocol) -> Bool {
        uiOrder[lhs] ?? 0 < uiOrder[rhs] ?? 0
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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
