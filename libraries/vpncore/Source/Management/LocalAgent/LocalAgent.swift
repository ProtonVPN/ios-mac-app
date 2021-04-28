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

protocol LocalAgentDelegate: AnyObject {
    func didReceiveError(code: Int)
    func didChangeState(state: LocalAgentState?)
}

protocol LocalAgent {
    var state: LocalAgentState? { get }
    var delegate: LocalAgentDelegate? { get set }

    func connect(host: String, data: VpnAuthenticationData, netshield: NetShieldType)
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

    init() {
        client = LocalAgentNativeClient()
        client.delegate = self
    }

    var state: LocalAgentState? {
        guard let currentState = agent?.state, !currentState.isEmpty else {
            return nil
        }

        return LocalAgentState.from(string: currentState)
    }

    weak var delegate: LocalAgentDelegate?

    func connect(host: String, data: VpnAuthenticationData, netshield: NetShieldType) {
        agent = LocalAgentAgentConnection(data.clientCertificate, clientKeyPEM: data.clientKey.base64X25519Representation, serverCAsPEM: rootCerts, host: host, client: client, features: LocalAgentFeatures.with(netshield: netshield))
    }

    func disconnect() {
        agent?.close()
    }

    func update(netshield: NetShieldType) {
        let features = LocalAgentFeatures.with(netshield: netshield)
        agent?.setFeatures(features)
    }

    func unjail() {
        let features = LocalAgentFeatures.with(jailed: false)
        agent?.setFeatures(features)
    }
}

extension GoLocalAgent: LocalAgentNativeClientDelegate {
    func didReceiveError(code: Int) {
        delegate?.didReceiveError(code: code)
    }

    func didChangeState(state: LocalAgentState?) {
        delegate?.didChangeState(state: state)
    }
}
