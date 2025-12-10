//
//  MacVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import CommonNetworking
import Dependencies
import Domain
import LegacyCommon
import VPNShared

final class MacVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    private let vpnAuthentication: VpnAuthentication
    private let appGroup: String

    init(vpnAuthentication: VpnAuthentication, appGroup: String) {
        self.vpnAuthentication = vpnAuthentication
        self.appGroup = appGroup
    }

    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            KeychainRefVpnCredentialsConfigurator()
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case .wireGuard:
            WGVpnCredentialsConfigurator(
                xpcServiceUser: XPCServiceUser(withExtension: SystemExtensionType.wireGuard.machServiceName, logger: { log.debug("\($0)", category: .protocol) })
            )
        }
    }
}
