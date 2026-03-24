//
//  SmartPortSelectorBridge.swift
//  Core
//
//  Created by Jaroslav Oo on 2021-08-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Domain
import Foundation
import VPNShared

public typealias SmartPortSelectorCompletion = ([Int]) -> Void

public protocol SmartPortSelector {
    func determineBestPort(for vpnProtocol: VpnProtocol, on server: ServerIp, completion: @escaping SmartPortSelectorCompletion)
}

public final class SmartPortSelectorImplementation: SmartPortSelector {
    private let wireguardUdpChecker: SmartProtocolAvailabilityChecker
    private let wireguardTcpChecker: SmartProtocolAvailabilityChecker

    public init(
        wireguardUdpChecker: SmartProtocolAvailabilityChecker,
        wireguardTcpChecker: SmartProtocolAvailabilityChecker
    ) {
        self.wireguardUdpChecker = wireguardUdpChecker
        self.wireguardTcpChecker = wireguardTcpChecker
    }

    public func determineBestPort(for vpnProtocol: VpnProtocol, on serverIp: ServerIp, completion: @escaping SmartPortSelectorCompletion) {
        let portOverrides = serverIp.protocolEntries?.overridePorts(using: vpnProtocol)

        // If we don't get a response on any ports, return all ports shuffled randomly
        let fallbackPorts = (portOverrides ?? wireguardUdpChecker.defaultPorts).shuffled()

        switch vpnProtocol {
        case let .wireGuard(transportProtocol): // Ping all the ports to determine which are available
            // If we're using a protocol other TCP or TLS, just return default TCP ports
            guard case .udp = transportProtocol else {
                // FUTUREDO: Implement
                let ports = portOverrides ?? wireguardTcpChecker.defaultPorts
                completion(ports)
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
                    log.debug("Retrying port selection", category: .connectionConnect)
                    guard let self else {
                        // VPNAPPL-3034 prevent self from being deallocated until retries are completed.
                        // Converting this class to a struct and removing [weak self] causes a SIGABRT.
                        log.debug("\(Self.self) deallocated before the retry attempt", category: .connectionConnect)
                        completion(fallbackPorts)
                        return
                    }
                    wireguardUdpChecker.getFirstToRespondPort(server: serverIp) { result in
                        if let port = result {
                            completion([port])
                            return
                        }

                        log.debug("No Wireguard ports responded even on second attempt, returning ports at random", category: .connectionConnect, event: .scan)
                        completion(fallbackPorts)
                    }
                }
            }

        case .ike: // Only port is used, so nothing to select
            let ports = portOverrides ?? DefaultConstants.ikeV2Ports
            completion(ports.shuffled())
        }
    }
}
