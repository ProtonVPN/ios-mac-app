//
//  VpnProtocol.swift
//  ProtonVPN - Created on 13.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

import VPNShared

import Domain
import Strings

extension VpnProtocol: @retroactive DefaultableProperty {
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
        case .ike: .credentials
        case .openVpn: .certificate
        case .wireGuard: .certificate
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

    public func encode(with _: NSCoder) {
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

    public func encode(with _: NSCoder) {
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

    public func encode(with _: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
