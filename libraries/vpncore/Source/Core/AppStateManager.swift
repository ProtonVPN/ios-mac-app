//
//  AppStateManager.swift
//  vpncore - Created on 26.06.19.
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

import Foundation
import Reachability
#if canImport(AppKit)
import AppKit
#endif

public protocol AppStateManagerFactory {
    func makeAppStateManager() -> AppStateManager
}

public protocol AppStateManager {
    var stateChange: Notification.Name { get }
    var displayStateChange: Notification.Name { get }
    var wake: Notification.Name { get }
    
    var state: AppState { get }
    var onVpnStateChanged: ((VpnState) -> Void)? { get set }

    // The state displayed to the user in the UI is not always the same as the "real" VPN state
    // For example when connected to the VPN and using local agent we do not want to show the user "Connected" because Internet is not yet available before the local agent connects
    // So we fake it with a "Loading connection info" display state
    var displayState: AppDisplayState { get }
    
    func isOnDemandEnabled(handler: @escaping (Bool) -> Void)
    
    func cancelConnectionAttempt()
    func cancelConnectionAttempt(completion: @escaping () -> Void)
        
    func prepareToConnect()
    func connect(withConfiguration configuration: ConnectionConfiguration)
    
    func disconnect()
    func disconnect(completion: @escaping () -> Void)
    
    func refreshState()
    func connectedDate(completion: @escaping (Date?) -> Void)
    func activeConnection() -> ConnectionConfiguration?
}

extension AppStateManager {
    public var stateChange: Notification.Name { Notification.Name("AppStateManagerStateChange") }
    public var displayStateChange: Notification.Name { Notification.Name("AppStateManagerDisplayStateChange") }
    public var wake: Notification.Name { Notification.Name("AppStateManagerWake") }
}

public class AppStateManagerImplementation: AppStateManager {
    
    private let networking: Networking
    private let vpnApiService: VpnApiService
    private var vpnManager: VpnManagerProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let serverStorage: ServerStorage = ServerStorageConcrete()
    private let timerFactory: TimerFactoryProtocol
    private let vpnKeychain: VpnKeychainProtocol
    private let configurationPreparer: VpnManagerConfigurationPreparer
        
    public weak var alertService: CoreAlertService?
    
    private var reachability: Reachability?

    private var _state: AppState = .disconnected
    public private(set) var state: AppState {
        get {
            #if DEBUG
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            return _state
        }
        set {
            #if DEBUG
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            _state = newValue
            computeDisplayState()
        }
    }

    public var displayState: AppDisplayState = .disconnected {
        didSet {
            guard displayState != oldValue else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }

                NotificationCenter.default.post(name: self.displayStateChange,
                                                object: self.displayState)
            }
        }
    }
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
    
    private var timeoutTimer: Timer?
    private var serviceChecker: ServiceChecker?

    private let vpnAuthentication: VpnAuthentication
    private let doh: DoHVPN
    
    public init(vpnApiService: VpnApiService, vpnManager: VpnManagerProtocol, networking: Networking, alertService: CoreAlertService, timerFactory: TimerFactoryProtocol, propertiesManager: PropertiesManagerProtocol, vpnKeychain: VpnKeychainProtocol, configurationPreparer: VpnManagerConfigurationPreparer, vpnAuthentication: VpnAuthentication, doh: DoHVPN) {
        self.vpnApiService = vpnApiService
        self.vpnManager = vpnManager
        self.networking = networking
        self.alertService = alertService
        self.timerFactory = timerFactory
        self.propertiesManager = propertiesManager
        self.vpnKeychain = vpnKeychain
        self.configurationPreparer = configurationPreparer
        self.vpnAuthentication = vpnAuthentication
        self.doh = doh
        
        handleVpnStateChange(vpnManager.state)
        reachability = try? Reachability()
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
                alertService?.push(alert: FirstTimeConnectingAlert())
            }
        }
        
        prepareServerCertificate()
        
        if vpnKeychain.hasOldVpnPassword() {
            try? vpnKeychain.clearOldVpnPassword()
            alertService?.push(alert: FirstTimeConnectingAlert())
        }
        
        if case VpnState.disconnecting = vpnState {
            stuckDisconnecting = true
        }
        
        state = .preparingConnection
        attemptingConnection = true
        beginTimoutCountdown()
        notifyObservers()
    }
    
    public func cancelConnectionAttempt() {
        cancelConnectionAttempt {}
    }
    
    public func cancelConnectionAttempt(completion: @escaping () -> Void) {
        state = .aborted(userInitiated: true)
        attemptingConnection = false
        cancelTimout()
        
        notifyObservers()
        
        disconnect(completion: completion)
    }
    
    public func refreshState() {
        vpnManager.refreshState()
    }
        
    public func connect(withConfiguration configuration: ConnectionConfiguration) { // swiftlint:disable:this cyclomatic_complexity
        guard let reachability = reachability else { return }
        if case AppState.aborted = state { return }
        
        if reachability.connection == .unavailable {
            notifyNetworkUnreachable()
            return
        }
        
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            if vpnCredentials.isDelinquent {
                let alert = UserBecameDelinquentAlert(reconnectionInfo: nil)
                alertService?.push(alert: alert)
                connectionFailed()
                return
            }
        } catch {
            connectionFailed()
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
        }
        
        lastAttemptedConfiguration = configuration
        
        attemptingConnection = true
        
        let serverAge = ServerStorageConcrete().fetchAge()
        if Date().timeIntervalSince1970 - serverAge > (2 * 60 * 60) {
            // if this is too common, then we should pick a random server instead of using really old score values
            log.warning("Connecting with scores older than 2 hours", category: .app, metadata: ["serverAge": "\(serverAge)"])
        }
                
        switch configuration.vpnProtocol.authenticationType {
        case .credentials:
            log.info("VPN connect started", category: .connectionConnect, metadata: ["protocol": "\(configuration.vpnProtocol)", "authenticationType": "\(configuration.vpnProtocol.authenticationType)"])
            makeConnection(configuration)
        case .certificate:
            log.info("Checking vpn auth keys and certificates", category: .connectionConnect)
            vpnAuthentication.loadAuthenticationData(features: VPNConnectionFeatures(propertiesManager: propertiesManager, vpnProtocol: configuration.vpnProtocol)) { result in
                switch result {
                case let .success(data):
                    log.info("VPN connect started", category: .connectionConnect, metadata: ["protocol": "\(configuration.vpnProtocol)", "authenticationType": "\(configuration.vpnProtocol.authenticationType)"])
                    self.makeConnection(configuration, authData: data)
                case .failure(let error):
                    log.error("Failed to load vpn auth data", category: .connectionConnect, metadata: ["protocol": "\(configuration.vpnProtocol)", "authenticationType": "\(configuration.vpnProtocol.authenticationType)"])
                    self.connectionFailed()
                    
                    let nsError = error as NSError
                    if nsError.code == 429 || nsError.code == 85092 {
                        self.alertService?.push(alert: TooManyCertificateRequestsAlert())
                    } else {
                        self.alertService?.push(alert: VPNAuthCertificateRefreshErrorAlert())
                    }
                }
            }
        }
    }

    public func disconnect() {
        disconnect {}
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        log.info("VPN disconnect started", category: .connectionDisconnect)
        propertiesManager.intentionallyDisconnected = true
        vpnManager.disconnect(completion: completion)
    }
    
    public func connectedDate(completion: @escaping (Date?) -> Void) {
        let savedDate = Date(timeIntervalSince1970: propertiesManager.lastConnectedTimeStamp)
        vpnManager.connectedDate { [weak self] (date) in
            if let connectionDate = date, connectionDate > savedDate {
                self?.propertiesManager.lastConnectedTimeStamp = connectionDate.timeIntervalSince1970
                completion(connectionDate)
            } else {
                completion(savedDate)
            }
        }
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
    
    private func beginTimoutCountdown() {
        cancelTimout()
        timeoutTimer = timerFactory.timer(timeInterval: 30, repeats: false, block: { [weak self] _ in
            self?.timeout()
        })
        timeoutTimer?.tolerance = 5.0
        RunLoop.current.add(timeoutTimer!, forMode: .default)
    }
    
    private func cancelTimout() {
        timeoutTimer?.invalidate()
    }
    
    @objc private func timeout() {
        log.info("Connection attempt timed out", category: .connectionConnect)
        state = .aborted(userInitiated: false)
        attemptingConnection = false
        cancelTimout()
        stopAttemptingConnection()
        notifyObservers()
    }
    
    private func stopAttemptingConnection() {
        log.info("Stop preparing connection", category: .connectionConnect)
        cancelTimout()
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
    
    private func makeConnection(_ connectionConfiguration: ConnectionConfiguration, authData: VpnAuthenticationData? = nil) {
        guard let vpnManagerConfiguration = configurationPreparer.prepareConfiguration(from: connectionConfiguration, authData: authData) else {
            cancelConnectionAttempt()
            return
        }
        
        switch connectionConfiguration.vpnProtocol {
        case .ike:
            self.propertiesManager.lastIkeConnection = connectionConfiguration
        case .openVpn:
            self.propertiesManager.lastOpenVpnConnection = connectionConfiguration
        case .wireGuard:
            self.propertiesManager.lastWireguardConnection = connectionConfiguration
        }
        
        vpnManager.connect(configuration: vpnManagerConfiguration, completion: {
            // COMPLETION
        })
    }
    
    private func setupReachability() {
        guard let reachability = reachability else {
            return
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            return
        }
    }
    
    private func startObserving() {
        vpnManager.stateChanged = { [weak self] in
            guard Thread.isMainThread else {
                return DispatchQueue.main.async {
                    self?.vpnStateChanged()
                }
            }
            self?.vpnStateChanged()
        }
        vpnManager.localAgentStateChanged = { [weak self] in
            guard Thread.isMainThread else {
                return DispatchQueue.main.async {
                    self?.computeDisplayState()
                }
            }
            self?.computeDisplayState()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(killSwitchChanged), name: type(of: propertiesManager).hasConnectedNotification, object: nil)
    }
    
    @objc private func vpnStateChanged() {
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
    
    @objc private func killSwitchChanged() {
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
        case .connecting(let descriptor):
            state = .connecting(descriptor)
        case .connected(let descriptor):
            propertiesManager.intentionallyDisconnected = false
            
            serviceChecker?.stop()
            if let alertService = alertService {
                serviceChecker = ServiceChecker(networking: networking, alertService: alertService, doh: doh)
            }
            attemptingConnection = false
            state = .connected(descriptor)
            cancelTimout()
        case .reasserting:
            return // usually this step is quick
        case .disconnecting(let descriptor):
            if attemptingConnection { // needs to disconnect before attempting to connect
                if case AppState.connecting = state {
                    stopAttemptingConnection()
                } else {
                    state = .preparingConnection
                }
            } else {
                state = .disconnecting(descriptor)
            }
        case .error(let error):
            state = .error(error)
        }
        
        if !state.isConnected {
            serviceChecker?.stop()
            serviceChecker = nil
        }
        
        notifyObservers()
    }
    // swiftlint:enable cyclomatic_complexity
    
    private func unknownError(_ vpnState: VpnState) {
        handleVpnStateChange(vpnState)
    }
    
    private func connectionFailed() {
        state = .error(NSError(code: 0, localizedDescription: ""))
        notifyObservers()
    }
    
    private func handleVpnError(_ vpnState: VpnState) {
        // In the rare event that the vpn is stuck not disconnecting, show a helpful alert
        if case VpnState.disconnecting(_) = vpnState, stuckDisconnecting {
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
        let dispatchGroup = DispatchGroup()
        
        var rSessionCount: Int?
        var rVpnCredentials: VpnCredentials?
        
        let failureClosure: (Error) -> Void = { error in
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        vpnApiService.sessionsCount { result in
            switch result {
            case let .success(sessionsCount):
                rSessionCount = sessionsCount
                dispatchGroup.leave()
            case let .failure(error):
                failureClosure(error)
            }
        }
        
        dispatchGroup.enter()
        vpnApiService.clientCredentials { result in
            switch result {
            case let .success(newVpnCredentials):
                rVpnCredentials = newVpnCredentials
                dispatchGroup.leave()
            case let .failure(error):
                failureClosure(error)
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            guard let `self` = self, self.state.isDisconnected else { return }
            
            if let sessionCount = rSessionCount, sessionCount >= (rVpnCredentials?.maxConnect ?? vpnCredentials.maxConnect) {
                #if canImport(AppKit)
                let notification = Notification(name: NSApplication.didChangeOcclusionStateNotification)
                NotificationCenter.default.post(notification)
                #endif
                let alert = MaxSessionsAlert(userCurrentCredentials: rVpnCredentials ?? vpnCredentials)
                self.alertService?.push(alert: alert)
                self.connectionFailed()
            } else if let newVpnCredentials = rVpnCredentials, newVpnCredentials.password != vpnCredentials.password {
                self.vpnKeychain.store(vpnCredentials: newVpnCredentials)
                guard let lastConfiguration = self.lastAttemptedConfiguration else {
                    return
                }
                if self.state.isDisconnected {
                    self.isOnDemandEnabled { enabled in
                        guard !enabled else { return }
                        log.info("Attempt connection after retrieving new credentials", category: .connectionConnect, event: .trigger)
                        self.connect(withConfiguration: lastConfiguration)
                    }
                }
            }
        }
    }
    
    private func notifyObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            NotificationCenter.default.post(name: self.stateChange, object: self.state)
        }
    }
    
    private func notifyNetworkUnreachable() {
        attemptingConnection = false
        cancelTimout()
        connectionFailed()
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.alertService?.push(alert: VpnNetworkUnreachableAlert())
        }
    }
    
    private func vpnStuck() {
        vpnManager.removeConfigurations(completionHandler: { [weak self] error in
            guard let `self` = self else { return }
            guard error == nil, self.reconnectingAfterStuckDisconnecting == false, let lastConfig = self.lastAttemptedConfiguration else {
                self.alertService?.push(alert: VpnStuckAlert())
                self.connectionFailed()
                return
            }
            self.reconnectingAfterStuckDisconnecting = true
            log.info("Attempt connection after vpn stuck", category: .connectionConnect, event: .trigger)
            self.connect(withConfiguration: lastConfig) // Retry connection
        })
    }

    private func computeDisplayState() {
        // not using local agent, use the real state
        guard let isLocalAgentConnected = vpnManager.isLocalAgentConnected else {
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
