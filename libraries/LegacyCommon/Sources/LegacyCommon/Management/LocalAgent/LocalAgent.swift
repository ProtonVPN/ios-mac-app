//
//  LocalAgent.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import Reachability
import Network

import Dependencies

import GoLibs

import Domain
import Ergonomics
import LocalFeatureFlags
import Timer
import VPNShared

import Home

private enum LocalAgentFeature: String, FeatureFlag {
    var category: String { "LocalAgent" }

    case connectionDetails = "ConnectionDetails"
}

protocol LocalAgentDelegate: AnyObject {
    func didReceiveError(error: LocalAgentError)
    func didChangeState(state: LocalAgentState)
    func didReceiveFeatures(_ features: VPNConnectionFeatures)
    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage)
    func netShieldStatsChanged(to stats: NetShieldModel)
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

public struct NetShieldStatsNotification: TypedNotification {
    public static var name = Notification.Name("ch.protonvpn.localagent.netshieldstats")
    public var data: NetShieldModel
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
            log.assertionFailure("LocalAgentNewAgentConnection should have returned error")
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

    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let propertiesManager: PropertiesManagerProtocol
    private let agentConnectionFactory: LocalAgentConnectionFactory
    @Dependency(\.timerFactory) var timerFactory

    private var agent: LocalAgentConnectionWrapper?
    private let client: LocalAgentNativeClientImplementation
    private let reachability: Reachability?

    private var previousState: LocalAgentState?
    private var statusTimer: BackgroundTimer?
    private var notificationTokens = [NotificationToken]()

    var isMonitoringFeatureStatistics: Bool { statusTimer?.isValid == true }
    private var isNetShieldStatsEnabled: Bool { propertiesManager.featureFlags.netShieldStats }

    init(factory: LocalAgentConnectionFactory, propertiesManager: PropertiesManagerProtocol, netShieldPropertyProvider: NetShieldPropertyProvider) {
        self.propertiesManager = propertiesManager
        self.netShieldPropertyProvider = netShieldPropertyProvider
        reachability = try? Reachability()
        client = LocalAgentNativeClientImplementation()
        agentConnectionFactory = factory
        client.delegate = self

        try? reachability?.startNotifier()

        // giving the agent a hint when connectivity is restored in case it is stuck in a back off
        reachability?.whenReachable = { [weak self] _ in self?.agent?.setConnectivity(true) }

        startObservingNetShieldCriteria()
    }

    private func startObservingNetShieldCriteria() {
        let notifications = [type(of: netShieldPropertyProvider).netShieldNotification, type(of: propertiesManager).featureFlagsNotification]
        notificationTokens = NotificationCenter.default.addObservers(for: notifications, object: nil) { [weak self] _ in
            self?.toggleStatusMonitoringIfNecessary()
        }
    }

    deinit {
        stopStatusMonitoringIfNecessary()
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
        log.debug(
            "Local agent connecting to \(configuration.hostname)",
            category: .localAgent,
            metadata: ["config": "\(configuration)"]
        )

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
        netShieldStatsChanged(to: .init(trackers: 0, ads: 0, data: 0, enabled: false))
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

    private func toggleStatusMonitoringIfNecessary() {
        let shouldMonitorStats = netShieldPropertyProvider.netShieldType == .level2
        log.debug("NetShield level: \(netShieldPropertyProvider.netShieldType), should monitor stats: \(shouldMonitorStats)", category: .localAgent)
        shouldMonitorStats ? startStatusMonitoringIfNecessary() : stopStatusMonitoringIfNecessary()
    }

    private func startStatusMonitoringIfNecessary() {
        guard isNetShieldStatsEnabled else {
            log.debug("Not starting stats monitoring, feature flag is false", category: .localAgent)
            return
        }

        if let timer = statusTimer, timer.isValid {
            log.debug("Not starting timer, work is already scheduled for \(timer.nextTime)", category: .localAgent)
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

    private func netShieldStatsChanged(to stats: NetShieldModel) {
        self.delegate?.netShieldStatsChanged(to: stats)
        NotificationCenter.default.post(NetShieldStatsNotification(data: stats), object: self)
    }
}

extension LocalAgentImplementation: LocalAgentNativeClientImplementationDelegate {
    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage) {
        guard LocalFeatureFlags.isEnabled(LocalAgentFeature.connectionDetails) else { return }

        delegate?.didReceiveConnectionDetails(details)
    }

    func didReceiveFeatureStatistics(_ statistics: FeatureStatisticsMessage) {
        guard isNetShieldStatsEnabled else { return }

        let stats: NetShieldModel = .init(
            trackers: statistics.netShield.trackersBlocked ?? 0,
            ads: statistics.netShield.adsBlocked ?? 0,
            data: statistics.netShield.bytesSaved,
            enabled: true)

        netShieldStatsChanged(to: stats)
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
            toggleStatusMonitoringIfNecessary()
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
