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
    private let openVpnTcpChecker: SmartProtocolAvailabilityChecker
    private let openVpnUdpChecker: SmartProtocolAvailabilityChecker
    private let wireguardChecker: SmartProtocolAvailabilityChecker

    init(openVpnTcpChecker: SmartProtocolAvailabilityChecker,
         openVpnUdpChecker: SmartProtocolAvailabilityChecker,
         wireguardChecker: SmartProtocolAvailabilityChecker) {
        self.openVpnTcpChecker = openVpnTcpChecker
        self.openVpnUdpChecker = openVpnUdpChecker
        self.wireguardChecker = wireguardChecker
    }
    
    func determineBestPort(for vpnProtocol: VpnProtocol, on serverIp: ServerIp, completion: @escaping SmartPortSelectorCompletion) {
        switch vpnProtocol {
        case .wireGuard: // Ping all the ports to determine which are available
            wireguardChecker.getFirstToRespondPort(server: serverIp) { result in
                if let port = result {
                    completion([port])
                } else {
                    completion(self.wireguardChecker.defaultPorts.shuffled())
                }
            }
            
        case .ike: // Only port is used, so nothing to select
            completion(DefaultConstants.ikeV2Ports)
            
        case .openVpn(let transport): // TunnelKit accepts array of ports and select appropriate port by itself
            switch transport {
            case .tcp:
                completion(openVpnTcpChecker.defaultPorts.shuffled())
            case .udp:
                completion(openVpnUdpChecker.defaultPorts.shuffled())
            }
        }
    }
}
