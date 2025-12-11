//
//  IOSVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonNetworking
import Dependencies
import Domain
import Foundation
import LegacyCommon
import VPNShared

final class IOSVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    private let vpnAuthentication: VpnAuthentication

    init(vpnAuthentication: VpnAuthentication) {
        self.vpnAuthentication = vpnAuthentication
    }

    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            KeychainRefVpnCredentialsConfigurator()
        case .wireGuard:
            WGiOSVpnCredentialsConfigurator()
        }
    }
}
