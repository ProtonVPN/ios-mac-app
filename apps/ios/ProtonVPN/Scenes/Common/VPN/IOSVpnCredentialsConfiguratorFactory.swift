//
//  IOSVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

import Dependencies

import Domain
import LegacyCommon
import VPNShared

final class IOSVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    private let vpnKeychain: VpnKeychainProtocol
    private let vpnAuthentication: VpnAuthentication

    init(vpnKeychain: VpnKeychainProtocol, vpnAuthentication: VpnAuthentication) {
        self.vpnKeychain = vpnKeychain
        self.vpnAuthentication = vpnAuthentication
    }

    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            KeychainRefVpnCredentialsConfigurator()
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case .wireGuard:
            WGiOSVpnCredentialsConfigurator(
                vpnKeychain: vpnKeychain
            )
        }
    }
}
