//
//  VpnManager+LocalAgent.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

import Domain
import LocalFeatureFlags
import ExtensionIPC
import VPNShared

import Home

private let localAgentQueue = DispatchQueue(label: "ch.protonvpn.apple.local-agent")

extension VpnManager {
    func connectLocalAgent(data: VpnAuthenticationData? = nil) {
        guard let vpnProtocol = self.currentVpnProtocol else {
            log.error("Skipping local agent connection, current protocol is nil!", category: .localAgent)
            return
        }
        guard vpnProtocol.authenticationType == .certificate else {
            log.info("Skipping local agent connection for protocol \(vpnProtocol)", category: .localAgent)
            return
        }

        let connect = { (data: VpnAuthenticationData) in
            localAgentQueue.sync { [unowned self] in
                guard let configuration = LocalAgentConfiguration(propertiesManager: self.propertiesManager, natTypePropertyProvider: self.natTypePropertyProvider, netShieldPropertyProvider: self.netShieldPropertyProvider, safeModePropertyProvider: self.safeModePropertyProvider, vpnProtocol: self.currentVpnProtocol) else {
                    log.error("Cannot reconnect to the local agent with missing configuraton", category: .localAgent, event: .error)
                    return
                }

                self.disconnectLocalAgentNoSync()
                self.localAgent = LocalAgentImplementation(factory: self.localAgentConnectionFactory,
                                                           propertiesManager: self.propertiesManager,
                                                           netShieldPropertyProvider: self.netShieldPropertyProvider)
                self.localAgent?.delegate = self
                self.localAgent?.connect(data: data, configuration: configuration)
            }
        }

        if let authenticationData = data {
            connect(authenticationData)
            return
        }

        // load last authentication data (that should be available)
        vpnAuthentication.loadAuthenticationData { [weak self] result in
            switch result {
            case .failure(let error):
                log.error("Failed to initialize local agent because of missing authentication data",
                          category: .localAgent, event: .error, metadata: ["error": .string(.init(describing: error))])
                guard let remoteClientError = error as? AuthenticationRemoteClientError else {
                    return
                }

                switch remoteClientError {
                case .needNewKeys:
                    self?.reconnectWithNewKeyAndCertificate()
                case .tooManyCertRequests(let retryAfter):
                    self?.alertService?.push(alert: TooManyCertificateRequestsAlert(retryAfter: retryAfter))
                }
            case let .success(data):
                connect(data)
            }
        }
    }

    private func disconnectLocalAgentNoSync() {
        if localAgent != nil {
            log.debug("Disconnecting Local agent", category: .localAgent)
        }

        isLocalAgentConnected = false
        localAgent?.disconnect()
        localAgent = nil
    }

    func disconnectLocalAgent() {
        localAgentQueue.sync {
            disconnectLocalAgentNoSync()
        }
    }

    func refreshCertificateWithError(completion: @escaping (VpnAuthenticationData) -> Void) {
        vpnAuthentication.refreshCertificates { [weak self] result in
            switch result {
            case let .success(data):
                completion(data)
            case let .failure(error):
                log.error("Failed to refresh certificate in local agent",
                          category: .localAgent, event: .error,
                          metadata: ["error": .string(.init(describing: error))])
                SentryHelper.shared?.log(error: error)

                if let remoteClientError = error as? AuthenticationRemoteClientError {
                    switch remoteClientError {
                    case .needNewKeys:
                        self?.reconnectWithNewKeyAndCertificate()
                    case .tooManyCertRequests(let retryAfter):
                        self?.alertService?.push(alert: TooManyCertificateRequestsAlert(retryAfter: retryAfter))
                    }
                    return
                }

                log.error("Trying to refresh expired or revoked certificate for current connection failed with \(error), showing error and disconnecting", category: .localAgent, event: .error)
                self?.alertService?.push(alert: VPNAuthCertificateRefreshErrorAlert())

                self?.connectionQueue.async { [weak self] in
                    // Don't disconnect the VPN on iOS if the app is in the background - our app could be getting
                    // "pre-warmed," and we may not have the necessary privileges to successfully execute a cert refresh.
                    #if os(iOS)
                    guard self?.disconnectOnCertRefreshError == true else {
                        return
                    }
                    #endif

                    self?.disconnect { [weak self] in
                        localAgentQueue.sync {
                            self?.localAgent?.disconnect()
                        }
                    }
                }
            }
        }
    }

    func reconnectWithNewKeyAndCertificate() {
        vpnAuthentication.clearEverything { [weak self] in
            // Force keygen on our end, otherwise we won't be able to fetch a certificate.
            _ = self?.vpnAuthentication.loadClientPrivateKey()
            self?.refreshCertificateWithError { result in
                log.debug("Generated new keys and got new certificate, asking to reconnect", category: .localAgent)
                executeOnUIThread {
                    NotificationCenter.default.post(name: VpnGateway.needsReconnectNotification, object: nil)
                }
            }
        }
    }

    func disconnectWithAlert(alert: SystemAlert) {
        disconnect { }
        alertService?.push(alert: alert)
    }

    var lastConnectionConfiguration: ConnectionConfiguration? {
        get {
            switch currentVpnProtocol {
            case .ike:
                return propertiesManager.lastIkeConnection
            case .openVpn:
                return propertiesManager.lastOpenVpnConnection
            case .wireGuard:
                return propertiesManager.lastWireguardConnection
            case nil:
                return nil
            }
        }
        set {
            switch currentVpnProtocol {
            case .ike:
                propertiesManager.lastIkeConnection = newValue
            case .openVpn:
                propertiesManager.lastOpenVpnConnection = newValue
            case .wireGuard:
                propertiesManager.lastWireguardConnection = newValue
            case nil:
                log.warning("Trying to set configuration without current protocol", category: .localAgent)
            }
        }
    }

    func updateActiveConnection(closure: @escaping ((ConnectionConfiguration?) -> ConnectionConfiguration?)) {
        lastConnectionConfiguration = closure(lastConnectionConfiguration)
    }

    func updateActiveConnection(netShieldType: NetShieldType) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(netShieldType: netShieldType)
        updateActiveConnection {
            log.info("Netshield type was \(String(describing: $0?.netShieldType)), updating to \(netShieldType).", category: .connection)
            return $0?.withChanged(netShieldType: netShieldType)
        }
    }

    func updateActiveConnection(natType: NATType) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(natType: natType)
        updateActiveConnection {
            log.info("NAT type was \(String(describing: $0?.natType)), updating to \(natType).", category: .connection)
            return $0?.withChanged(natType: natType)
        }
    }

    func updateActiveConnection(safeMode: Bool) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(safeMode: safeMode)
        updateActiveConnection {
            log.info("Safe mode was \(String(describing: $0?.safeMode)), updating to \(safeMode).", category: .connection)
            return $0?.withChanged(safeMode: safeMode)
        }
    }

    func updateActiveConnection(exitIp: String) {
        updateActiveConnection {
            log.info("Server IP was \($0?.serverIp.exitIp ?? "(nil)"), updating to \(exitIp).", category: .connection)
            return $0?.withChanged(exitIp: exitIp)
        }
    }

    /// Updates last connection config that is used to display proper info in apps UI.
    private func updateActiveConnection(serverId: String, ipId: String) {
        let servers = serverStorage.fetch()
        guard let newServer = servers.first(where: { $0.id == serverId }) else {
            log.warning("Server with such id not found", category: .connection, event: .error, metadata: ["serverId": "\(serverId)"])
            return
        }
        guard let newIp = newServer.ips.first(where: { $0.id == ipId }) else {
            log.warning("Server IP with such id not found", category: .connection, event: .error, metadata: ["ipId": "\(ipId)", "serverId": "\(serverId)"])
            return
        }
        propertiesManager.lastPreparedServer = newServer
        updateActiveConnection {
            log.info("Server was \(String(describing: $0?.server.id)) with ip: \(String(describing: $0?.serverIp.id)), updating to \(String(describing: newServer.id)) with ip \(String(describing: newIp.id)).", category: .connection)
            return $0?.withChanged(server: newServer, ip: newIp)
        }
    }

    // Danger: If you're adding another `updateActiveConnection` here, consider also updating `lastConnectionRequest`.

    /// Asks NE for currently connected logical and ip ids. If these are not as expected last connection configuration is updated, so UI can show up-to-date info.
    func checkActiveServer() {
        guard LocalFeatureFlags.isEnabled(VpnReconnectionFeatureFlag()) else { return }
        guard case .connected = state else { return }
        log.debug("Checking if NE is still connected to the same server", category: .connection)
        self.currentVpnProtocolFactory?.vpnProviderManager(for: .configuration, completion: { manager, error in
            guard let manager = manager else {
                log.error("No vpn manager found", category: .localAgent, event: .error)
                return
            }
            let sender = manager.vpnConnection as? ProviderMessageSender
            sender?.send(WireguardProviderRequest.getCurrentLogicalAndServerId) { result in
                switch result {
                case .success(let response):
                    guard case .ok(let data) = response, let data = data, let ids = String(data: data, encoding: .utf8) else {
                        log.error("Error while decoding getCurrentLogicalAndServerId response", category: .connection, event: .error)
                        return
                    }
                    let id = ids.components(separatedBy: ";")

                    guard self.lastConnectionConfiguration?.server.id != id[0], self.lastConnectionConfiguration?.serverIp.id != id[1] else {
                        log.info("Current vpn server is as expected", category: .connection)
                        return
                    }

                    self.updateActiveConnection(serverId: id[0], ipId: id[1])
                    self.disconnectLocalAgent()
                    self.connectLocalAgent()

                case .failure(let error):
                    log.error("Error while getting currently connected vpn server and ip: \(error)", category: .connection, event: .error)
                }
            }
        })
    }

}

extension VpnManager: LocalAgentDelegate {
    // swiftlint:disable cyclomatic_complexity
    func didReceiveError(error: LocalAgentError) {
        switch error {
        case .certificateExpired, .certificateNotProvided:
            log.error("Local agent reported expired or missing, trying to refresh and reconnect", category: .localAgent, event: .error)
            refreshCertificateWithError { [weak self] data in
                log.info("Reconnecting to local agent with new certificate", category: .localAgent)
                self?.connectLocalAgent(data: data)
            }
        case .badCertificateSignature, .certificateRevoked:
            log.error("Local agent reported invalid certificate signature or revoked certificate, trying to generate new key and certificate and reconnect", category: .localAgent, event: .error)
            reconnectWithNewKeyAndCertificate()
        case .keyUsedMultipleTimes:
            log.error("Key used multiple times, trying to generate new key and certificate and reconnect", category: .localAgent, event: .error)
            reconnectWithNewKeyAndCertificate()
        case .maxSessionsBasic, .maxSessionsPro, .maxSessionsFree, .maxSessionsPlus, .maxSessionsUnknown, .maxSessionsVisionary:
            disconnect { }
            guard let credentials = try? vpnKeychain.fetchCached() else {
                log.error("Cannot show max session alert because getting credentials failed", category: .localAgent, event: .error)
                return
            }
            alertService?.push(alert: MaxSessionsAlert(accountPlan: credentials.accountPlan))
        case .serverError:
            log.error("Server error occurred, showing the user an alert and disconnecting", category: .localAgent, event: .error)
            disconnectWithAlert(alert: VpnServerErrorAlert())
        case .guestSession:
            log.error("Internal status that should never be seen, check the app implementation", category: .localAgent, event: .error)
            disconnect { }
        case .policyViolationDelinquent:
            log.error("Disconnecting because of unpaid invoices", category: .localAgent, event: .error)
            disconnectWithAlert(alert: DelinquentUserAlert())
        case .policyViolationLowPlan:
            disconnectWithAlert(alert: VpnServerSubscriptionErrorAlert())
        case .userTorrentNotAllowed:
            log.error("Received torrent not allowed error from LocalAgent (doing nothing for now, ServiceChecker will handle it)")
        case .userBadBehavior:
            log.error("Local agent reporting bad behavior, kicking client", category: .localAgent, event: .error)
            disconnect { }
        case .restrictedServer:
            log.error("Local agent reported restricted server error, waiting for the local agent to recover", category: .localAgent, event: .error)
        case .serverSessionDoesNotMatch:
            log.error("Server session does not match, trying to generate new key and certificate and reconnect", category: .localAgent, event: .error)
            reconnectWithNewKeyAndCertificate()
        case let .systemError(error):
            log.error("Local agent reported system error for \(error), the setting will be reverted, showing alert to the user", category: .localAgent, event: .error)
            alertService?.push(alert: LocalAgentSystemErrorAlert(error: error))
        }
    }
    // swiftlint:enable cyclomatic_complexity

    func didChangeState(state: LocalAgentState) {
        log.debug("Local agent state changed to \(state)", category: .localAgent, event: .stateChange)

        isLocalAgentConnected = state == .connected

        switch state {
        case .clientCertificateError:
            // Because the local agent shared library does not return certificate expired error when connecting with expired certificate 🤷‍♀️
            // Instead use this state as the certificate expired error
            didReceiveError(error: LocalAgentError.certificateExpired)

        case .serverCertificateError:
            #if os(iOS)
            // Most probably NE has changed the server. Let's check if it is the case
            // (currently only iOS NE can change server).
            checkActiveServer()
            #endif

        default:
            break
        }
    }

    func didReceiveFeatures(_ features: VPNConnectionFeatures) {
        didReceiveFeature(netshield: features.netshield)
        didReceiveFeature(vpnAccelerator: features.vpnAccelerator)
        didReceiveFeature(natType: features.natType)
        didReceiveFeature(safeMode: features.safeMode)

        if vpnAuthentication.shouldIgnoreFeatureChanges {
            return // Don't try (and fail) to retrieve stored features if we don't have to
        }

        let storedFeatures = vpnAuthenticationStorage.getStoredCertificateFeatures()
        guard !features.equals(other: storedFeatures, safeModeFeatureEnabled: safeModePropertyProvider.safeMode != nil) else {
            return
        }

        // If features are different from the ones we have in current certificate, refresh it
        vpnAuthentication.refreshCertificates(features: features, completion: { [weak self] result in
            switch result {
            case .failure(let error):
                log.error("Failed to refresh certificate in local agent after receiving features",
                          category: .localAgent, event: .error,
                          metadata: ["error": .string(.init(describing: error))])
                SentryHelper.shared?.log(error: error)

                guard let remoteClientError = error as? AuthenticationRemoteClientError else {
                    return
                }

                switch remoteClientError {
                case .needNewKeys:
                    self?.reconnectWithNewKeyAndCertificate()
                case .tooManyCertRequests(let retryAfter):
                    self?.alertService?.push(alert: TooManyCertificateRequestsAlert(retryAfter: retryAfter))
                }
            case .success:
                break
            }
        })
    }

    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage) {
        if let exitIp = details.exitIp {
            self.updateActiveConnection(exitIp: String(describing: exitIp))
        }
    }

    func netShieldStatsChanged(to stats: NetShieldModel) {
        netShieldStats = stats
    }

    private func didReceiveFeature(safeMode: Bool?) {
        // ignore nil value received from the Local Agent and also nil value from the provider because it means the feature is not enabled and values should not be used
        guard let currentSafeMode = safeModePropertyProvider.safeMode, let safeMode = safeMode, currentSafeMode != safeMode else {
            return
        }

        log.debug("Safe Mode was set to \(currentSafeMode), changing to \(safeMode) received from local agent", category: .localAgent, event: .stateChange)
        safeModePropertyProvider.safeMode = safeMode
    }
    
    private func didReceiveFeature(vpnAccelerator: Bool) {
        let localValue = featurePropertyProvider.getValue(for: VPNAccelerator.self)
        let localAgentValue: VPNAccelerator = vpnAccelerator ? .on : .off

        if localValue == localAgentValue {
            return
        }

        log.debug(
            "Updating VPNAccelerator setting to value received from local agent",
            category: .localAgent,
            event: .stateChange,
            metadata: ["localValue": "\(localValue)", "localAgentValue": "\(localAgentValue)"]
        )
        featurePropertyProvider.setValue(localAgentValue)
    }

    private func didReceiveFeature(netshield: NetShieldType) {
        guard netShieldPropertyProvider.netShieldType != netshield else {
            return
        }

        log.debug("Netshield was set to \(netShieldPropertyProvider.netShieldType), changing to \(netshield) received from local agent", category: .localAgent, event: .stateChange)
        updateActiveConnection(netShieldType: netshield)
        netShieldPropertyProvider.netShieldType = netshield
    }

    private func didReceiveFeature(natType: NATType) {
        guard natTypePropertyProvider.natType != natType else {
            return
        }

        log.debug("NAT type was set to \(natTypePropertyProvider.natType), changing to \(natType) received from local agent", category: .localAgent, event: .stateChange)
        natTypePropertyProvider.natType = natType
    }
}

// This lets us not depend on LocalFeatureFlags in VPNShared library
extension VPNShared.VpnReconnectionFeatureFlag: FeatureFlag { }
