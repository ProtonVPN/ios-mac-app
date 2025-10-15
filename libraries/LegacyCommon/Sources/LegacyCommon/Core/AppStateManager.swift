//
//  AppStateManager.swift
//  vpncore - Created on 26.06.19.
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

import Foundation
#if canImport(AppKit)
    import AppKit
#endif
import Combine

import Dependencies
import Reachability
import Sharing

import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Timer
import VPNAppCore
import VPNShared

public protocol AppStateManagerFactory {
    func makeAppStateManager() -> AppStateManager
}

public protocol AppStateManager {
    var state: AppState { get }
    var onVpnStateChanged: ((VpnState) -> Void)? { get set }

    /// Helper to get app state in a thread safe manner when async calls can be used
    @MainActor
    var stateThreadSafe: AppState { get }

    // The state displayed to the user in the UI is not always the same as the "real" VPN state
    // For example when connected to the VPN and using local agent we do not want to show the user "Connected" because Internet is not yet available before the local agent connects
    // So we fake it with a "Loading connection info" display state
    var displayState: AppDisplayState { get }

    func isOnDemandEnabled(handler: @escaping (Bool) -> Void)

    func cancelConnectionAttempt()
    func cancelConnectionAttempt(completion: @escaping () -> Void)

    func prepareToConnect()
    func checkNetworkConditionsAndCredentialsAndConnect(withConfiguration configuration: ConnectionConfiguration)

    func disconnect()
    func disconnect(completion: @escaping () -> Void)

    func refreshState()
    func connectedDate() async -> Date?
    func activeConnection() -> ConnectionConfiguration?
}

public extension AppStateManager {
    @MainActor
    var stateThreadSafe: AppState { state }
}

public class AppStateManagerImplementation: AppStateManager {
    private let networking: Networking
    private let vpnApiService: VpnApiService
    private var vpnManager: VpnManagerProtocol
    @Dependency(\.propertiesManager) private var propertiesManager
    private let timerFactory: TimerFactory
    private let vpnKeychain: VpnKeychainProtocol
    private let configurationPreparer: VpnManagerConfigurationPreparer

    public weak var alertService: CoreAlertService?

    // Be aware that `whenReachable` handler is used in `checkNetworkConditionsAndCredentialsAndConnect` on macOS
    private var reachability: Reachability?

    private var _state: AppState = .disconnected
    public private(set) var state: AppState {
        get {
            dispatchAssert(condition: .onQueue(.main))
            return _state
        }
        set {
            dispatchAssert(condition: .onQueue(.main))
            _state = newValue
            computeDisplayState(with: vpnManager.isLocalAgentConnected)
        }
    }

    public var displayState: AppDisplayState = .disconnected {
        didSet {
            guard displayState != oldValue else {
                return
            }
            displayStateStreamContinuation.yield(displayState)

            DispatchQueue.main.async { [displayState] in
                AppEvent.appStateManagerDisplayStateChange.post(displayState)
            }
        }
    }

    private var (displayStateStream, displayStateStreamContinuation) = AsyncStream<AppDisplayState>.makeStream()

    private var vpnState: VpnState = .invalid {
        didSet {
            onVpnStateChanged?(vpnState)
        }
    }

    public var onVpnStateChanged: ((VpnState) -> Void)?
    private var lastAttemptedConfiguration: ConnectionConfiguration?
    private var attemptingConnection = false
    private var stuckDisconnecting = false {
        didSet {
            if stuckDisconnecting == false {
                reconnectingAfterStuckDisconnecting = false
            }
        }
    }

    private var reconnectingAfterStuckDisconnecting = false

    private var timeoutTimer: BackgroundTimer?
    private var serviceChecker: ServiceChecker?

    private let vpnAuthentication: VpnAuthentication

    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.safeModePropertyProvider) private var safeModePropertyProvider

    public typealias Factory =
        CoreAlertServiceFactory &
        NetworkingFactory &
        TimerFactoryCreator & VpnApiServiceFactory &
        VpnAuthenticationFactory &
        VpnKeychainFactory &
        VpnManagerConfigurationPreparerFactory &
        VpnManagerFactory

    public convenience init(_ factory: Factory) {
        self.init(
            vpnApiService: factory.makeVpnApiService(),
            vpnManager: factory.makeVpnManager(),
            networking: factory.makeNetworking(),
            alertService: factory.makeCoreAlertService(),
            timerFactory: factory.makeTimerFactory(),
            vpnKeychain: factory.makeVpnKeychain(),
            configurationPreparer: factory.makeVpnManagerConfigurationPreparer(),
            vpnAuthentication: factory.makeVpnAuthentication()
        )
    }

    public init(
        vpnApiService: VpnApiService,
        vpnManager: VpnManagerProtocol,
        networking: Networking,
        alertService: CoreAlertService,
        timerFactory: TimerFactory,
        vpnKeychain: VpnKeychainProtocol,
        configurationPreparer: VpnManagerConfigurationPreparer,
        vpnAuthentication: VpnAuthentication
    ) {
        self.vpnApiService = vpnApiService
        self.vpnManager = vpnManager
        self.networking = networking
        self.alertService = alertService
        self.timerFactory = timerFactory
        self.vpnKeychain = vpnKeychain
        self.configurationPreparer = configurationPreparer
        self.vpnAuthentication = vpnAuthentication

        handleVpnStateChange(vpnManager.state)
        self.reachability = try? Reachability()
        setupReachability()
        startObserving()
    }

    deinit {
        reachability?.stopNotifier()
    }

    public func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        vpnManager.isOnDemandEnabled(handler: handler)
    }

    public func prepareToConnect() {
        if !propertiesManager.hasConnected {
            switch vpnState {
            case .disconnecting:
                vpnStuck()
                return
            default:
                break
            }
        }

        prepareServerCertificate()

        if case VpnState.disconnecting = vpnState {
            stuckDisconnecting = true
        }

        state = .preparingConnection
        attemptingConnection = true
        beginTimeoutCountdown()
        notifyObservers()
    }

    public func cancelConnectionAttempt() {
        cancelConnectionAttempt {}
    }

    public func cancelConnectionAttempt(completion: @escaping () -> Void) {
        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
        state = .aborted(userInitiated: true)
        attemptingConnection = false
        cancelTimeout()

        notifyObservers()

        disconnect(completion: completion)
    }

    public func refreshState() {
        vpnManager.refreshState()
    }

    public func checkNetworkConditionsAndCredentialsAndConnect(withConfiguration configuration: ConnectionConfiguration) {
        guard let reachability else { return }
        if case AppState.aborted = state { return }

        if reachability.connection == .unavailable {
            #if os(macOS)
                // we want to show the alert if app was not launched at login, or if it was, then after a small delay
                if AppStartup.isLaunchedAtLogin {
                    let timeAmount: TimeInterval = 10
                    if let processStartDate = AppStartup.processStartDate, -processStartDate.timeIntervalSinceNow < timeAmount {
                        // App has been launched at login within the last `timeAmount` seconds.
                        let retryWorkItem = DispatchWorkItem { [weak self] in
                            self?.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: configuration)
                        }
                        reachability.whenReachable = { [weak self, retryWorkItem] _ in
                            // if reachability changes within the time window, let's cancel the scheduling and retry calling the method
                            retryWorkItem.cancel()
                            self?.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: configuration)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + timeAmount, execute: retryWorkItem)
                        return
                    }
                }
                reachability.whenReachable = nil // cleanup
            #endif
            // let's finally show the alert if:
            //     - !os(macOS)
            // OR  - app wasn't launched at login
            // OR  - we gave it some delay but reachability is still unavailable
            notifyNetworkUnreachable()
            return
        }

        do {
            let vpnCredentials = try vpnKeychain.fetchCached()
            if vpnCredentials.isDelinquent {
                let alert = UserBecameDelinquentAlert(reconnectInfo: nil)
                alertService?.push(alert: alert)
                connectionFailed()
                return
            }
        } catch {
            connectionFailed()
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return
        }

        guard !configuration.ports.isEmpty else {
            connectionFailed()
            return
        }

        lastAttemptedConfiguration = configuration

        attemptingConnection = true

        // ServerStorage no longer exists. If we want to continue logging this, we should use the timestamp stored for VPNAPPL-2078
        // let serverAge = serverStorage.fetchAge()
        // if Date().timeIntervalSince1970 - serverAge > (2 * 60 * 60) {
        //     if this is too common, then we should pick a random server instead of using really old score values
        //     log.warning("Connecting with scores older than 2 hours", category: .app, metadata: ["serverAge": "\(serverAge)"])
        // }

        switch configuration.vpnProtocol.authenticationType {
        case .credentials:
            log.info("VPN connect started", category: .connectionConnect, metadata: ["protocol": "\(configuration.vpnProtocol)", "authenticationType": "\(configuration.vpnProtocol.authenticationType)"])
            configureVPNManagerAndConnect(configuration)
        case .certificate:
            let clientKey = vpnAuthentication.loadClientPrivateKey()
            configureVPNManagerAndConnect(configuration, clientPrivateKey: clientKey)
        }
    }

    public func disconnect() {
        disconnect {}
    }

    public func disconnect(completion: @escaping () -> Void) {
        log.info("VPN disconnect started", category: .connectionDisconnect)
        propertiesManager.intentionallyDisconnected = true

        #if os(macOS)
            propertiesManager.connectedServerNameDoNotUse = nil
        #endif

        vpnManager.disconnect(completion: completion)
    }

    public func connectedDate() async -> Date? {
        await vpnManager.connectedDate()
    }

    public func activeConnection() -> ConnectionConfiguration? {
        guard let currentVpnProtocol = vpnManager.currentVpnProtocol else {
            return nil
        }

        switch currentVpnProtocol {
        case .ike:
            return propertiesManager.lastIkeConnection
        case .openVpn:
            return propertiesManager.lastOpenVpnConnection
        case .wireGuard:
            return propertiesManager.lastWireguardConnection
        }
    }

    // MARK: - Private functions

    private func beginTimeoutCountdown() {
        cancelTimeout()

        timeoutTimer = timerFactory.scheduledTimer(
            runAt: Date().addingTimeInterval(30),
            leeway: .seconds(5),
            queue: .main
        ) { [weak self] in
            self?.timeout()
        }
    }

    private func cancelTimeout() {
        timeoutTimer?.invalidate()
    }

    private func timeout() {
        log.info("Connection attempt timed out", category: .connectionConnect)
        state = .aborted(userInitiated: false)
        attemptingConnection = false
        cancelTimeout()
        stopAttemptingConnection()
        notifyObservers()
    }

    private func stopAttemptingConnection() {
        log.info("Stop preparing connection", category: .connectionConnect)
        cancelTimeout()
        handleVpnError(vpnState)
        disconnect()
    }

    private func prepareServerCertificate() {
        do {
            _ = try vpnKeychain.getServerCertificate()
        } catch {
            try? vpnKeychain.storeServerCertificate()
        }
    }

    private func configureVPNManagerAndConnect(_ connectionConfiguration: ConnectionConfiguration, clientPrivateKey: PrivateKey? = nil) {
        guard let vpnManagerConfiguration = configurationPreparer.prepareConfiguration(from: connectionConfiguration, clientPrivateKey: clientPrivateKey) else {
            cancelConnectionAttempt()
            return
        }

        switch connectionConfiguration.vpnProtocol {
        case .ike:
            propertiesManager.lastIkeConnection = connectionConfiguration
        case .openVpn:
            propertiesManager.lastOpenVpnConnection = connectionConfiguration
        case .wireGuard:
            propertiesManager.lastWireguardConnection = connectionConfiguration
        }

        vpnManager.disconnectAnyExistingConnectionAndPrepareToConnect(with: vpnManagerConfiguration, completion: {
            // COMPLETION
        })
    }

    private func setupReachability() {
        guard let reachability else {
            return
        }

        do {
            try reachability.startNotifier()
        } catch {
            return
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    private func startObserving() {
        vpnManager.stateChanged = { [weak self] in
            executeOnUIThread {
                self?.vpnStateChanged()
            }
        }
        vpnManager.localAgentStateChanged = { [weak self] localAgentConnectedState in
            executeOnUIThread {
                self?.computeDisplayState(with: localAgentConnectedState)
            }
        }
        @Shared(.killSwitch) var killSwitch: Bool
        $killSwitch.publisher.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.killSwitchChanged()
        }.store(in: &cancellables)

        #if os(macOS)
            if VPNFeatureFlagType.portForwarding.enabled {
                Task {
                    for await displayState in displayStateStream {
                        switch displayState {
                        case .connected:
                            vpnManager.startNATPortMappingService()
                        default:
                            vpnManager.stopNATPortMappingService()
                        }
                    }
                }
            }
        #endif
    }

    private func vpnStateChanged() {
        reachability?.whenReachable = nil

        let newState = vpnManager.state
        switch newState {
        case .error:
            if case VpnState.invalid = vpnState {
                vpnState = newState
                return // otherwise shows connecting failed on first attempt
            } else if attemptingConnection {
                stopAttemptingConnection()
            }
        default:
            break
        }

        vpnState = newState
        handleVpnStateChange(newState)
    }

    @objc
    private func killSwitchChanged() {
        if state.isConnected {
            propertiesManager.intentionallyDisconnected = true
            vpnManager.setOnDemand(propertiesManager.hasConnected)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func handleVpnStateChange(_ vpnState: VpnState) {
        if case VpnState.disconnecting = vpnState {} else {
            stuckDisconnecting = false
        }

        switch vpnState {
        case .invalid:
            return // NEVPNManager hasn't initialised yet
        case .disconnected:
            if attemptingConnection {
                state = .preparingConnection
                return
            } else {
                state = .disconnected
            }
        case let .connecting(descriptor):
            state = .connecting(descriptor)
        case let .connected(descriptor):
            propertiesManager.intentionallyDisconnected = false

            #if os(macOS)
                propertiesManager.connectedServerNameDoNotUse = activeConnection()?.server.name
            #endif

            serviceChecker?.stop()
            if let alertService {
                serviceChecker = ServiceChecker(networking: networking, alertService: alertService)
            }
            attemptingConnection = false
            state = .connected(descriptor)
            cancelTimeout()
        case .reasserting:
            return // usually this step is quick
        case let .disconnecting(descriptor):
            if attemptingConnection { // needs to disconnect before attempting to connect
                if case AppState.connecting = state {
                    stopAttemptingConnection()
                } else {
                    state = .preparingConnection
                }
            } else {
                state = .disconnecting(descriptor)
            }
        case let .error(error):
            state = .error(error)
        }

        if !state.isConnected {
            serviceChecker?.stop()
            serviceChecker = nil
        }

        notifyObservers()
    }

    // swiftlint:enable cyclomatic_complexity

    private func connectionFailed() {
        state = .error(CommonVpnError.connectionFailed)
        notifyObservers()
    }

    private func handleVpnError(_ vpnState: VpnState) {
        // In the rare event that the vpn is stuck not disconnecting, show a helpful alert
        if case VpnState.disconnecting = vpnState, stuckDisconnecting {
            log.error("Stale VPN connection failing to disconnect", category: .connectionConnect)
            vpnStuck()
            return
        }

        attemptingConnection = false

        do {
            let vpnCredentials = try vpnKeychain.fetch()
            checkApiForFailureReason(vpnCredentials: vpnCredentials)
        } catch {
            connectionFailed()
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }

    private func checkApiForFailureReason(vpnCredentials: VpnCredentials) {
        Task {
            let rSessionCount = try? await vpnApiService.sessionsCount().sessionCount
            let rVpnCredentials = try? await vpnApiService.clientCredentials()
            await MainActor.run { [weak self] in
                guard let self, state.isDisconnected else {
                    return
                }

                if let sessionCount = rSessionCount, sessionCount >= (rVpnCredentials?.maxConnect ?? vpnCredentials.maxConnect) {
                    let accountTier = rVpnCredentials?.maxTier ?? vpnCredentials.maxTier
                    maxSessionsReached(accountTier: accountTier)
                } else if let newVpnCredentials = rVpnCredentials, newVpnCredentials.password != vpnCredentials.password {
                    vpnKeychain.storeAndDetectDowngrade(vpnCredentials: newVpnCredentials)
                    guard let lastConfiguration = lastAttemptedConfiguration else {
                        return
                    }
                    if state.isDisconnected {
                        isOnDemandEnabled { enabled in
                            guard !enabled else { return }
                            log.info("Attempt connection after retrieving new credentials", category: .connectionConnect, event: .trigger)
                            self.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: lastConfiguration)
                        }
                    }
                }
            }
        }
    }

    private func maxSessionsReached(accountTier: Int) {
        #if canImport(AppKit)
            let notification = Notification(name: NSApplication.didChangeOcclusionStateNotification)
            NotificationCenter.default.post(notification)
        #endif
        let alert = MaxSessionsAlert(accountTier: accountTier)
        alertService?.push(alert: alert)
        connectionFailed()
    }

    private func notifyObservers() {
        DispatchQueue.main.async {
            AppEvent.appStateManagerStateChange.post(self.state)
        }
    }

    private func notifyNetworkUnreachable() {
        attemptingConnection = false
        cancelTimeout()
        connectionFailed()

        DispatchQueue.main.async {
            self.alertService?.push(alert: VpnNetworkUnreachableAlert())
        }
    }

    private func vpnStuck() {
        vpnManager.removeConfigurations(completionHandler: { [weak self] error in
            guard let self else {
                return
            }

            guard error == nil, reconnectingAfterStuckDisconnecting == false, let lastConfig = lastAttemptedConfiguration else {
                alertService?.push(alert: VpnStuckAlert())
                connectionFailed()
                return
            }
            reconnectingAfterStuckDisconnecting = true
            log.info("Attempt connection after vpn stuck", category: .connectionConnect, event: .trigger)
            checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: lastConfig) // Retry connection
        })
    }

    private func computeDisplayState(with localAgentConnectedState: Bool?) {
        // not using local agent, use the real state
        guard let isLocalAgentConnected = localAgentConnectedState else {
            displayState = state.asDisplayState()
            return
        }

        // connected to VPN tunnel but the local agent is not connected yet, pretend the VPN is still connecting
        // this is not only for local agent being in connected state but also in disconnected, etc when we do not have a good state to show to the user so we show loading connection info
        if !isLocalAgentConnected, case AppState.connected = state, !propertiesManager.intentionallyDisconnected {
            log.debug("Showing state as Loading connection info because local agent not connected yet", category: .connectionConnect)
            displayState = .loadingConnectionInfo
            return
        }

        displayState = state.asDisplayState()
    }
}
