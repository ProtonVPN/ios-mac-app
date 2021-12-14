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
    func didReceiveFeatures(_ features: VPNConnectionFeatures)
}

protocol LocalAgent {
    var state: LocalAgentState? { get }
    var delegate: LocalAgentDelegate? { get set }

    func connect(data: VpnAuthenticationData, configuration: LocalAgentConfiguration)
    func disconnect()
    func update(netshield: NetShieldType)
    func update(vpnAccelerator: Bool)
    func unjail()
}

final class LocalAgentImplementation: LocalAgent {
    private var agent: LocalAgentAgentConnection?
    private let client: LocalAgentNativeClientImplementation
    private let reachability: Reachability?

    private var previousState: LocalAgentState?

    init() {
        reachability = try? Reachability()
        client = LocalAgentNativeClientImplementation()
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

    func connect(data: VpnAuthenticationData, configuration: LocalAgentConfiguration) {
        log.debug("Local agent connecting to \(configuration.hostname)", category: .localAgent, metadata: ["config": "\(configuration)"])

        var error: NSError?
        agent = LocalAgentNewAgentConnection(data.clientCertificate, data.clientKey.derRepresentation, rootCerts, "10.2.0.1:65432", configuration.hostname, client, LocalAgentNewFeatures()?.with(configuration: configuration), true, &error)

        if let agentInitError = error {
            log.error("Creating Go local agent connection failed with \(agentInitError)", category: .localAgent)
        }
    }

    func disconnect() {
        agent?.close()
    }

    func update(netshield: NetShieldType) {
        let features = LocalAgentNewFeatures()?.with(netshield: netshield)
        agent?.setFeatures(features)
    }

    func update(vpnAccelerator: Bool) {
        let features = LocalAgentNewFeatures()?.with(vpnAccelerator: vpnAccelerator)
        agent?.setFeatures(features)
    }

    func unjail() {
        let features = LocalAgentNewFeatures()?.with(jailed: false)
        agent?.setFeatures(features)
    }
}

extension LocalAgentImplementation: LocalAgentNativeClientImplementationDelegate {
    func didReceiveError(code: Int) {
        guard let error = LocalAgentError.from(code: code) else {
            log.error("Ignoring unknown local agent error", category: .localAgent, event: .error)
            return
        }

        delegate?.didReceiveError(error: error)
    }

    func didChangeState(state: LocalAgentState?) {
        guard let state = state else {
            return
        }

        defer {
            // always save the previous state, but at the end of the call because it is needed for some comparisons
            previousState = state
        }

        // only inform about state change when the state really changes
        // e.g: changing Netshield in Connected state causes the local agent shared library to invoke onState with Connected again, just with different features
        if previousState != state {
            delegate?.didChangeState(state: state)
        }

        // Here come some conditions when the features received from the local agent shared library need to be ignored
        // The main reason is that those features are not "right" and the app using them to change settings would result in connecting with wrong Netshield level or VPN accelerator on next connection or reconnection

        // only check received features in Connected state
        // the problem here is that states like HardJailed reset Netshield in features to off
        guard state == .connected else {
            log.debug("Not checking features in \(state) state")
            return
        }

        // ignore the first time the features are received right after connecting
        // in this state the local agent shared library reports features from previous connection
        if previousState == .connecting, state == .connected {
            log.debug("Not checking features right after connecting", category: .localAgent, event: .stateChange)
            return
        }

        guard let features = agent?.status?.features else {
            // getting features is not guaranteed
            return
        }

        // the features are just reported, the local agent does not know what the current values in the app are
        // it is up to the app to compare them and decide what to do

        if let vpnFeatures = features.vpnFeatures {
            delegate?.didReceiveFeatures(vpnFeatures)
        }
        
    }
}
