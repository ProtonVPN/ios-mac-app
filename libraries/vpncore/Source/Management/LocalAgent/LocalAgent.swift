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
import GoLibs
import Reachability
import VPNShared
import Network
import LocalFeatureFlags
import Dependencies
import Timer

private enum LocalAgentFeature: String, FeatureFlag {
    var category: String { "LocalAgent" }

    case connectionDetails = "ConnectionDetails"
}

protocol LocalAgentDelegate: AnyObject {
    func didReceiveError(error: LocalAgentError)
    func didChangeState(state: LocalAgentState)
    func didReceiveFeatures(_ features: VPNConnectionFeatures)
    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage)
    func netShieldStatsChanged(to stats: NetShieldStats)
}

protocol LocalAgent {
    var state: LocalAgentState? { get }
    var delegate: LocalAgentDelegate? { get set }

    func connect(data: VpnAuthenticationData, configuration: LocalAgentConfiguration)
    func disconnect()
    func update(netshield: NetShieldType)
    func update(vpnAccelerator: Bool)
    func update(natType: NATType)
    func update(safeMode: Bool)
    func unjail()
    func requestStatus(withStats shouldRequestStats: Bool)
}

public struct NetShieldStatsNotification: StrongNotification {
    public static var name: Notification.Name { Notification.Name("ch.protonvpn.localagent.netshieldstats") }
    public var data: NetShieldStats
}

public protocol LocalAgentConnectionWrapper {
    var state: String { get }
    var status: LocalAgentStatusMessage? { get }
    func close()
    func setConnectivity(_: Bool)
    func setFeatures(_: LocalAgentFeatures?)
    func sendGetStatus(_: Bool)
}

extension LocalAgentAgentConnection: LocalAgentConnectionWrapper {
}

public protocol LocalAgentConnectionFactoryCreator {
    func makeLocalAgentConnectionFactory() -> LocalAgentConnectionFactory
}

public protocol LocalAgentConnectionFactory {
    // Wrapper function for LocalAgentAgentConnection for unit testing.
    // swiftlint:disable:next function_parameter_count
    func makeLocalAgentConnection(clientCertPEM: String,
                                  clientKeyPEM: String,
                                  serverCAsPEM: String,
                                  host: String,
                                  certServerName: String,
                                  client: LocalAgentNativeClientProtocol,
                                  features: LocalAgentFeatures?,
                                  connectivity: Bool) throws -> LocalAgentConnectionWrapper
}

public final class LocalAgentConnectionFactoryImplementation: LocalAgentConnectionFactory {
    // swiftlint:disable:next function_parameter_count
    public func makeLocalAgentConnection(clientCertPEM: String,
                                         clientKeyPEM: String,
                                         serverCAsPEM: String,
                                         host: String,
                                         certServerName: String,
                                         client: LocalAgentNativeClientProtocol,
                                         features: LocalAgentFeatures?,
                                         connectivity: Bool) throws -> LocalAgentConnectionWrapper {
        var error: NSError?
        let result = LocalAgentNewAgentConnection(clientCertPEM,
                                                  clientKeyPEM,
                                                  serverCAsPEM,
                                                  host,
                                                  certServerName,
                                                  client,
                                                  features,
                                                  connectivity,
                                                  &error)

        if let error = error {
            throw error
        }

        guard let result = result else {
            assertionFailure("LocalAgentNewAgentConnection should have returned error")
            throw LocalAgentError.serverError
        }

        return result
    }

    public init() { }
}

final class LocalAgentImplementation: LocalAgent {
    private static let localAgentHostname = "10.2.0.1:65432"
    private static let refreshInterval: TimeInterval = 60.0
    private static let refreshLeeway: DispatchTimeInterval = .seconds(5)
    private static let statusRequestQueue = DispatchQueue(label: "ch.protonvpn.vpnmanager.netshield")

    private var propertiesManager: PropertiesManagerProtocol
    private var agentConnectionFactory: LocalAgentConnectionFactory
    @Dependency(\.timerFactory) var timerFactory

    private var agent: LocalAgentConnectionWrapper?
    private let client: LocalAgentNativeClientImplementation
    private let reachability: Reachability?

    private var previousState: LocalAgentState?
    private var statusTimer: BackgroundTimer?

    private lazy var isNetShieldStatsEnabled = LocalFeatureFlags.isEnabled(NetShieldFeatureFlag.netShieldStats)
        && propertiesManager.featureFlags.netShieldStats

    init(factory: LocalAgentConnectionFactory, propertiesManager: PropertiesManagerProtocol) {
        self.propertiesManager = propertiesManager
        reachability = try? Reachability()
        client = LocalAgentNativeClientImplementation()
        agentConnectionFactory = factory
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

        do {
            agent = try agentConnectionFactory.makeLocalAgentConnection(clientCertPEM: data.clientCertificate,
                                                                        clientKeyPEM: data.clientKey.derRepresentation,
                                                                        serverCAsPEM: rootCerts,
                                                                        host: Self.localAgentHostname,
                                                                        certServerName: configuration.hostname,
                                                                        client: client,
                                                                        features: LocalAgentNewFeatures()?.with(configuration: configuration),
                                                                        connectivity: true)
        } catch {
            log.error("Creating local agent connection failed with \(error)", category: .localAgent)
        }
    }

    func disconnect() {
        agent?.close()
        netShieldStatsChanged(to: .zero)
    }

    func requestStatus(withStats shouldRequestStats: Bool) {
        agent?.sendGetStatus(shouldRequestStats)
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

    func update(natType: NATType) {
        let features = LocalAgentNewFeatures()?.with(natType: natType)
        agent?.setFeatures(features)
    }

    func update(safeMode: Bool) {
        let features = LocalAgentNewFeatures()?.with(safeMode: safeMode)
        agent?.setFeatures(features)
    }

    private func toggleStatusMonitoringIfNecessary(forFeatures features: VPNConnectionFeatures) {
        // If the server is reporting NetShield type as level2, we should be monitoring NetShieldStats
        guard isNetShieldStatsEnabled else { return }

        let shouldMonitorStats = features.netshield == .level2
        log.debug("Should monitor stats: \(shouldMonitorStats)")
        shouldMonitorStats ? startStatusMonitoringIfNecessary() : stopStatusMonitoringIfNecessary()
    }

    private func startStatusMonitoringIfNecessary() {
        if let timer = statusTimer, timer.isValid {
            log.debug("Not starting timer, a request is already scheduled for \(timer.nextTime)", category: .localAgent)
            return
        }
        log.debug("Starting status request background timer", category: .localAgent)
        statusTimer = timerFactory.scheduledTimer(
            runAt: Date(),
            repeating: Self.refreshInterval,
            leeway: Self.refreshLeeway,
            queue: Self.statusRequestQueue
        ) { [weak self] in
            self?.requestStatus(withStats: true)
        }
    }

    private func stopStatusMonitoringIfNecessary() {
        let wasMonitoring = statusTimer?.isValid == true
        log.debug("Stopping status monitoring. WasMonitoring: \(wasMonitoring)", category: .localAgent)
        statusTimer?.invalidate()
        statusTimer = nil
    }

    private func netShieldStatsChanged(to stats: NetShieldStats) {
        DispatchQueue.main.async {
            self.delegate?.netShieldStatsChanged(to: stats)
            NotificationCenter.default.post(NetShieldStatsNotification(data: stats), object: self)
        }
    }
}

extension LocalAgentImplementation: LocalAgentNativeClientImplementationDelegate {
    func didReceiveConnectionDetails(details: LocalAgentConnectionDetails) {
        guard LocalFeatureFlags.isEnabled(LocalAgentFeature.connectionDetails) else { return }

        let detailsMessage = ConnectionDetailsMessage(details: details)
        delegate?.didReceiveConnectionDetails(detailsMessage)
    }

    func didReceiveFeatureStatistics(_ dictionary: LocalAgentStringToValueMap) {
        guard isNetShieldStatsEnabled else { return }

        do {
            let statistics = try FeatureStatisticsMessage(localAgentStatsDictionary: dictionary)

            let stats = NetShieldStats(
                adsBlocked: statistics.netShield.adsBlocked ?? 0,
                malwareBlocked: statistics.netShield.malwareBlocked ?? 0,
                trackersBlocked: statistics.netShield.trackersBlocked ?? 0,
                bytesSaved: statistics.netShield.bytesSaved)

            netShieldStatsChanged(to: stats)
        } catch {
            log.error("Failed to decode feature stats", category: .localAgent, event: .error, metadata: ["error": "\(error)"])
        }
    }

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
            log.debug("Not checking features in \(state) state", category: .localAgent, event: .stateChange)
            return
        }

        // ignore the first time the features are received right after connecting
        // in this state the local agent shared library reports features from previous connection
        if previousState == .connecting, state == .connected {
            log.debug("Not checking features right after connecting", category: .localAgent, event: .stateChange)
            // Request status with feature statistics; the response will also contain the correct features too
            startStatusMonitoringIfNecessary()
            return
        }

        guard let features = agent?.status?.features else {
            // getting features is not guaranteed
            return
        }

        // the features are just reported, the local agent does not know what the current values in the app are
        // it is up to the app to compare them and decide what to do

        if let vpnFeatures = features.vpnFeatures {
            toggleStatusMonitoringIfNecessary(forFeatures: vpnFeatures)
            delegate?.didReceiveFeatures(vpnFeatures)
        }
        
    }
}

public struct NetShieldStats {
    public let adsBlocked: Int
    public let malwareBlocked: Int
    public let trackersBlocked: Int
    public let bytesSaved: Int64

    public static var zero: NetShieldStats {
        return NetShieldStats(adsBlocked: 0, malwareBlocked: 0, trackersBlocked: 0, bytesSaved: 0)
    }
}
