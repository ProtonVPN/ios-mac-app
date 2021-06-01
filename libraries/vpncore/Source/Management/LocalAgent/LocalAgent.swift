//
//  LocalAgent.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import WireguardSRP
import Reachability

protocol LocalAgentDelegate: AnyObject {
    func didReceiveError(error: LocalAgentError)
    func didChangeState(state: LocalAgentState)
}

protocol LocalAgent {
    var state: LocalAgentState? { get }
    var delegate: LocalAgentDelegate? { get set }

    func connect()
    func disconnect()
    func update(netshield: NetShieldType)
    func unjail()
}

protocol LocalAgentFactory {
    func createLocalAgent() -> LocalAgent
}

final class GoLocalAgent: LocalAgent {
    private var agent: LocalAgentAgentConnection?
    private let client: LocalAgentNativeClient
    private let reachability: Reachability?

    private let data: VpnAuthenticationData
    private let netshield: NetShieldType
    private let vpnAccelerator: Bool

    init(data: VpnAuthenticationData, netshield: NetShieldType, vpnAccelerator: Bool) {
        self.data = data
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator

        reachability = try? Reachability()
        client = LocalAgentNativeClient()
        client.delegate = self

        try? reachability?.startNotifier()

        // giving the agent a hint when connectivity is restored in case it is stuck in a back off
        reachability?.whenReachable = { [weak self] _ in self?.agent?.setConnectivity(true) }
    }

    deinit {
        reachability?.stopNotifier()
        agent?.close()
    }

    var state: LocalAgentState? {
        guard let currentState = agent?.state, !currentState.isEmpty else {
            return nil
        }
        return LocalAgentState.from(string: currentState)
    }

    weak var delegate: LocalAgentDelegate?

    func connect() {
        agent = LocalAgentAgentConnection(data.clientCertificate, clientKeyPEM: data.clientKey.derRepresentation, serverCAsPEM: rootCerts, host: "10.2.0.1:65432", client: client, features: LocalAgentFeatures()?.with(netshield: netshield).with(vpnAccelerator: vpnAccelerator).with(jailed: false), connectivity: true)
    }

    func disconnect() {
        agent?.close()
    }

    func update(netshield: NetShieldType) {
        let features = LocalAgentFeatures()?.with(netshield: netshield)
        agent?.setFeatures(features)
    }

    func unjail() {
        let features = LocalAgentFeatures()?.with(jailed: false)
        agent?.setFeatures(features)
    }
}

extension GoLocalAgent: LocalAgentNativeClientDelegate {
    func didReceiveError(code: Int) {
        guard let error = LocalAgentError.from(code: code) else {            
            return
        }

        delegate?.didReceiveError(error: error)
    }

    func didChangeState(state: LocalAgentState?) {
        guard let state = state else {
            return
        }

        delegate?.didChangeState(state: state)
    }
}
