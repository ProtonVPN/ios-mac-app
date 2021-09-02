//
//  SmartPortSelector.swift
//  Core
//
//  Created by Jaroslav Oo on 2021-08-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

typealias SmartPortSelectorCompletion = ([Int]) -> Void

protocol SmartPortSelector {
    func determineBestPort(for vpnProtocol: VpnProtocol, on server: ServerIp, completion: @escaping SmartPortSelectorCompletion)
}

final class SmartPortSelectorImplementation {
    
    private let openVpnConfig: OpenVpnConfig
    private let wireguardConfig: WireguardConfig
    
    init(openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig) {
        self.openVpnConfig = openVpnConfig
        self.wireguardConfig = wireguardConfig
    }
    
    func determineBestPort(for vpnProtocol: VpnProtocol, on serverIp: ServerIp, completion: @escaping SmartPortSelectorCompletion) {
        switch vpnProtocol {
        case .wireGuard: // Ping all the ports to determine which are available
            let checker = WireguardAvailabilityChecker(config: wireguardConfig)
            checker.getFirtToRespondPort(server: serverIp) { result in
                if let port = result {
                    completion([port])
                } else {
                    completion(self.wireguardConfig.defaultPorts.shuffled())
                }
            }
            
        case .ike: // Only port is used, so nothing to select
            completion(DefaultConstants.ikeV2Ports)
            
        case .openVpn(let transportProtocol): // TunnelKit accepts array of ports and select appropriate port by itself
            switch transportProtocol {
            case .udp:
                completion(openVpnConfig.defaultUdpPorts.shuffled())
            case .tcp, .undefined:
                completion(openVpnConfig.defaultTcpPorts.shuffled())
            }
        }
    }
}
