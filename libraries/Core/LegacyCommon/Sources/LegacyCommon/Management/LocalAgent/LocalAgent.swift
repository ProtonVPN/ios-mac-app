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
import Network

import Dependencies

import GoLibs

import NetShield
import VPNShared

import Domain
import Ergonomics
import Timer

import Combine
import NetShield

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
    func update(portForwarding: Bool)
    func unjail()
    func requestStatus(withStats shouldRequestStats: Bool)
}

public protocol LocalAgentConnectionWrapper: AnyObject {
    var state: String { get }
    var status: LocalAgentStatusMessage? { get }
    func close()
    func setConnectivity(_: Bool)
    func setFeatures(_: LocalAgentFeatures?)
    func sendGetStatus(_: Bool)
}

extension LocalAgentAgentConnection: LocalAgentConnectionWrapper {}

public protocol LocalAgentConnectionFactoryCreator {
    func makeLocalAgentConnectionFactory() -> LocalAgentConnectionFactory
}

public protocol LocalAgentConnectionFactory {
    // Wrapper function for LocalAgentAgentConnection for unit testing.
    // swiftlint:disable:next function_parameter_count
    func makeLocalAgentConnection(
        clientCertPEM: String,
        clientKeyPEM: String,
        serverCAsPEM: String,
        host: String,
        certServerName: String,
        client: LocalAgentNativeClientProtocol,
        features: LocalAgentFeatures?,
        connectivity: Bool
    ) throws -> LocalAgentConnectionWrapper
}

public final class LocalAgentConnectionFactoryImplementation: LocalAgentConnectionFactory {
    // swiftlint:disable:next function_parameter_count
    public func makeLocalAgentConnection(
        clientCertPEM: String,
        clientKeyPEM: String,
        serverCAsPEM: String,
        host: String,
        certServerName: String,
        client: LocalAgentNativeClientProtocol,
        features: LocalAgentFeatures?,
        connectivity: Bool
    ) throws -> LocalAgentConnectionWrapper {
        var error: NSError?
        let result = LocalAgentNewAgentConnection(
            clientCertPEM,
            clientKeyPEM,
            serverCAsPEM,
            host,
            certServerName,
            client,
            features,
            connectivity,
            0,
            0,
            &error
        )

        if let error {
            throw error
        }

        guard let result else {
            log.assertionFailure("LocalAgentNewAgentConnection should have returned error")
            throw LocalAgentError.serverError
        }

        return result
    }

    public init() {}
}

final class LocalAgentImplementation: LocalAgent {
    private static let localAgentHostname = "10.2.0.1:65432"
    private static let refreshInterval: Duration = .seconds(60)
    private static let refreshLeeway: Duration = .seconds(5)
    private static let monitorQueue = DispatchQueue(label: "ch.protonvpn.localAgent.monitorQueue")

    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.propertiesManager) private var propertiesManager
    private let agentConnectionFactory: LocalAgentConnectionFactory

    private var agent: LocalAgentConnectionWrapper?
    // TODO: VPNAPPL-3218 Prevent this object from leaking
    // The property below is leaking due to gomobile memory management.
    private let client: LocalAgentNativeClientImplementation
    private let networkMonitor = NetworkPathMonitor.shared

    private var lastReceivedStats: NetShieldModel?
    private var previousState: LocalAgentState?
    private var statusTask: Task<Void, Error>?
    private var notificationTokens = [NotificationToken]()
    private var networkMonitorCancellable: AnyCancellable?
    private var netShieldObserverTask: Task<Void, any Error>?

    var isMonitoringFeatureStatistics: Bool {
        guard let statusTask else {
            return false
        }
        return !statusTask.isCancelled
    }

    private var isNetShieldStatsEnabled: Bool { propertiesManager.featureFlags.netShieldStats }

    init(factory: LocalAgentConnectionFactory) {
        self.client = LocalAgentNativeClientImplementation()
        self.agentConnectionFactory = factory
        client.delegate = self

        // giving the agent a hint when connectivity is restored in case it is stuck in a back off
        self.networkMonitorCancellable = networkMonitor
            .pathSubject
            .map { path in
                switch path.status {
                case .satisfied:
                    return true
                case .unsatisfied:
                    return false
                case .requiresConnection:
                    // The path is not currently available, but establishing a new connection may activate the path.
                    return true
                @unknown default:
                    // let's hope for the best here :)
                    return true
                }
            }
            .removeDuplicates() // we only want toggles and not calling twice in a row `setConnectivity` with the same value
            .receive(on: localAgentQueue)
            .sink { [weak self] newConnectivityValue in
                self?.setConnectivity(newConnectivityValue)
            }

        networkMonitor.start(onQueue: Self.monitorQueue)

        startObservingNetShieldCriteria()
    }

    private func startObservingNetShieldCriteria() {
        // Observe feature flags changes via NotificationCenter (legacy)
        let notifications = [AppEvent.featureFlags.name]
        notificationTokens = NotificationCenter.default.addObservers(for: notifications, object: nil) { [weak self] _ in
            self?.toggleStatusMonitoringIfNecessary()
        }

        // Observe NetShield type changes via AsyncStream (modern)
        netShieldObserverTask = Task { [weak self] in
            guard let stream = self?.netShieldPropertyProvider.netShieldTypeStream() else {
                return
            }
            for await _ in stream {
                try Task.checkCancellation()
                self?.toggleStatusMonitoringIfNecessary()
            }
        }
    }

    deinit {
        stopStatusMonitoringIfNecessary()
        networkMonitor.stop()
        netShieldObserverTask?.cancel()
        agent?.close()
        agent = nil
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
            agent = try agentConnectionFactory.makeLocalAgentConnection(
                clientCertPEM: data.clientCertificate,
                clientKeyPEM: data.clientKey.derRepresentation,
                serverCAsPEM: rootCerts,
                host: Self.localAgentHostname,
                certServerName: configuration.hostname,
                client: client,
                features: LocalAgentNewFeatures()?.with(configuration: configuration),
                connectivity: networkMonitor.currentPath.status == .satisfied
            )
        } catch {
            log.error("Creating local agent connection failed with \(error)", category: .localAgent)
        }
    }

    func disconnect() {
        agent?.close()
        netShieldStatsChanged(to: .zero(enabled: false))
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

    func update(portForwarding: Bool) {
        let features = LocalAgentNewFeatures()?.with(portForwarding: portForwarding)
        agent?.setFeatures(features)
    }

    func setConnectivity(_ connectivity: Bool) {
        // we want to make sure we're not in a disconnected state due to a previous `close()` otherwise Go might panic!
        if let agent, LocalAgentState.from(string: agent.state) != .disconnected {
            log.info("Sending connectivity update to \(connectivity)", category: .localAgent)
            agent.setConnectivity(connectivity)
        }
    }

    private func toggleStatusMonitoringIfNecessary() {
        let shouldMonitorStats = netShieldPropertyProvider.getNetShieldType() == .level2
        log.debug("NetShield level: \(netShieldPropertyProvider.getNetShieldType()), should monitor stats: \(shouldMonitorStats)", category: .localAgent)
        shouldMonitorStats ? startStatusMonitoringIfNecessary() : stopStatusMonitoringIfNecessary()
    }

    private func startStatusMonitoringIfNecessary() {
        guard isNetShieldStatsEnabled else {
            log.debug("Not starting stats monitoring, feature flag is false", category: .localAgent)
            return
        }

        if let statusTask, !statusTask.isCancelled {
            log.debug("Not starting timer, work is already scheduled", category: .localAgent)
            return
        }
        log.debug("Starting status request background timer", category: .localAgent)
        statusTask = Task { @MainActor [weak self] in
            @Dependency(\.continuousClock) var clock
            for await _ in clock.timer(interval: Self.refreshInterval, tolerance: Self.refreshLeeway) {
                self?.requestStatus(withStats: true)
            }
        }
    }

    private func stopStatusMonitoringIfNecessary() {
        let wasMonitoring = isMonitoringFeatureStatistics
        log.debug("Stopping status monitoring. WasMonitoring: \(wasMonitoring)", category: .localAgent)
        statusTask?.cancel()
        statusTask = nil
    }

    private func netShieldStatsChanged(to stats: NetShieldModel) {
        delegate?.netShieldStatsChanged(to: stats)
        NotificationCenter.default.post(NetShieldStatsNotification(data: stats), object: self)
    }
}

extension LocalAgentImplementation: LocalAgentNativeClientImplementationDelegate {
    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage) {
        delegate?.didReceiveConnectionDetails(details)
    }

    func didReceiveFeatureStatistics(_ statistics: FeatureStatisticsMessage) {
        guard isNetShieldStatsEnabled else { return }

        let stats: NetShieldModel = .init(
            trackersCount: statistics.netShield.trackersBlocked ?? 0,
            adsCount: statistics.netShield.adsBlocked ?? 0,
            dataSaved: UInt64(statistics.netShield.bytesSaved),
            enabled: true
        )

        lastReceivedStats = stats
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
        guard let state else {
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
            if vpnFeatures.netshield != .level2 {
                let disabledStats = lastReceivedStats?.copy(enabled: false) ?? .zero(enabled: false)
                netShieldStatsChanged(to: disabledStats)
            }
            delegate?.didReceiveFeatures(vpnFeatures)
        }
    }
}
