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

final class SmartPortSelectorImplementation: SmartPortSelector {
    private let openVpnTcpChecker: SmartProtocolAvailabilityChecker
    private let openVpnUdpChecker: SmartProtocolAvailabilityChecker
    private let wireguardUdpChecker: SmartProtocolAvailabilityChecker
    private let wireguardTcpChecker: SmartProtocolAvailabilityChecker

    init(openVpnTcpChecker: SmartProtocolAvailabilityChecker,
         openVpnUdpChecker: SmartProtocolAvailabilityChecker,
         wireguardUdpChecker: SmartProtocolAvailabilityChecker,
         wireguardTcpChecker: SmartProtocolAvailabilityChecker) {
        self.openVpnTcpChecker = openVpnTcpChecker
        self.openVpnUdpChecker = openVpnUdpChecker
        self.wireguardUdpChecker = wireguardUdpChecker
        self.wireguardTcpChecker = wireguardTcpChecker
    }
    
    func determineBestPort(for vpnProtocol: VpnProtocol, on serverIp: ServerIp, completion: @escaping SmartPortSelectorCompletion) {
        switch vpnProtocol {
        case .wireGuard(let transportProtocol): // Ping all the ports to determine which are available
            guard case .udp = transportProtocol else {
                // FUTUREDO: Implement
                let ports = serverIp.protocolEntries?[vpnProtocol]??.ports ?? wireguardTcpChecker.defaultPorts
                completion(ports.shuffled())
                return
            }

            wireguardUdpChecker.getFirstToRespondPort(server: serverIp) { result in
                if let port = result {
                    completion([port])
                    return
                }

                log.debug("No Wireguard ports responded when trying to get the best port, waiting a bit and trying one more time.", category: .connectionConnect, event: .scan)

                // In case no Wireguard ports respon we wait a bit and try again just to be sure
                // If no port respond on the second attempt we return an empty array which will cause a connection failure
                // This is better than returning shuffled port for the app to connect with a random one
                // because it might cause the app to think it is connected even if it is not and result in various local agent failures
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.wireguardUdpChecker.getFirstToRespondPort(server: serverIp) { result in
                        if let port = result {
                            completion([port])
                            return
                        }

                        log.debug("No Wireguard ports responded even on second attempt, returning empty array to fail the connection.", category: .connectionConnect, event: .scan)
                        completion([])
                    }
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
