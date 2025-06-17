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

public extension VpnProtocol { // Authentication
    enum AuthenticationType {
        case credentials
        case certificate
    }

    var authenticationType: AuthenticationType {
        switch self {
        case .ike: .credentials
        case .openVpn: .certificate
        case .wireGuard: .certificate
        }
    }
}

// MARK: - NSCoding (used by Profile)

public extension VpnProtocol {
    private enum CoderKey {
        static let vpnProtocol = "vpnProtocol"
        static let transportProtocol = "transportProtocol"
    }

    init?(coder aDecoder: NSCoder) {
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

    func encode(with _: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}

public extension OpenVpnTransport {
    private enum CoderKey {
        static let transportProtocol = "transportProtocol"
    }

    init(coder aDecoder: NSCoder) {
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

    func encode(with _: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}

public extension WireGuardTransport {
    private enum CoderKey {
        static let transportProtocol = "transportProtocol"
    }

    init(coder aDecoder: NSCoder) {
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

    func encode(with _: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
