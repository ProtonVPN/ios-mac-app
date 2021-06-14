//
//  LocalAgentConfiguration.swift
//  Core
//
//  Created by Igor Kulman on 11.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

struct LocalAgentConfiguration {
    let hostname: String
    let netshield: NetShieldType
    let vpnAccelerator: Bool
    let bouncing: String?

    init(hostname: String, netshield: NetShieldType, vpnAccelerator: Bool, bouncing: String?) {
        self.hostname = hostname
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator
        self.bouncing = bouncing
    }
}

extension LocalAgentConfiguration {
    init(configuration: VpnManagerConfiguration) {
        self.init(hostname: configuration.hostname, netshield: configuration.netShield, vpnAccelerator: configuration.vpnAccelerator, bouncing: configuration.bouncing)
    }

    init?(propertiesManager: PropertiesManagerProtocol, vpnProtocol: VpnProtocol?) {
        let configuration: ConnectionConfiguration?
        switch vpnProtocol {
        case .ike:
            configuration = propertiesManager.lastIkeConnection
        case .openVpn:
            configuration = propertiesManager.lastOpenVpnConnection
        case .wireGuard:
            configuration = propertiesManager.lastWireguardConnection
        case nil:
            configuration = nil
        }

        guard let connectionConfiguration = configuration else {
            return nil
        }

        self.init(hostname: connectionConfiguration.server.domain, netshield: propertiesManager.netShieldType ?? .off, vpnAccelerator: !propertiesManager.featureFlags.isVpnAccelerator || propertiesManager.vpnAcceleratorEnabled, bouncing: connectionConfiguration.serverIp.label)
    }
}
