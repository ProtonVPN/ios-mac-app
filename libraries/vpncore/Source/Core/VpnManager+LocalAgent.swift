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

private let localAgentQueue = DispatchQueue(label: "ch.protonvpn.apple.local-agent")

extension VpnManager {
    func connectLocalAgent(data: VpnAuthenticationData? = nil) {
        guard self.currentVpnProtocol?.authenticationType == .certificate else {
            return
        }

        let connect = { (data: VpnAuthenticationData) in
            localAgentQueue.sync { [unowned self] in
                guard let configuration = LocalAgentConfiguration(propertiesManager: self.propertiesManager, natTypePropertyProvider: self.natTypePropertyProvider, netShieldPropertyProvider: self.netShieldPropertyProvider, safeModePropertyProvider: self.safeModePropertyProvider, vpnProtocol: self.currentVpnProtocol) else {
                    log.error("Cannot reconnect to the local agent with missing configuraton", category: .localAgent, event: .error)
                    return
                }

                self.disconnectLocalAgentNoSync()
                self.localAgent = LocalAgentImplementation(factory: self.localAgentConnectionFactory)
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
            self?.refreshCertificateWithError { _ in
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

    func updateActiveConnection(netShieldType: NetShieldType) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(netShieldType: netShieldType)
        switch currentVpnProtocol {
        case .ike:
            propertiesManager.lastIkeConnection = propertiesManager.lastIkeConnection?.withChanged(netShieldType: netShieldType)
        case .openVpn:
            propertiesManager.lastOpenVpnConnection = propertiesManager.lastOpenVpnConnection?.withChanged(netShieldType: netShieldType)
        case .wireGuard:
            propertiesManager.lastWireguardConnection = propertiesManager.lastWireguardConnection?.withChanged(netShieldType: netShieldType)
        case nil:
            break
        }
    }

    func updateActiveConnection(natType: NATType) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(natType: natType)
        switch currentVpnProtocol {
        case .ike:
            propertiesManager.lastIkeConnection = propertiesManager.lastIkeConnection?.withChanged(natType: natType)
        case .openVpn:
            propertiesManager.lastOpenVpnConnection = propertiesManager.lastOpenVpnConnection?.withChanged(natType: natType)
        case .wireGuard:
            propertiesManager.lastWireguardConnection = propertiesManager.lastWireguardConnection?.withChanged(natType: natType)
        case nil:
            break
        }
    }

    func updateActiveConnection(safeMode: Bool) {
        propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(safeMode: safeMode)
        switch currentVpnProtocol {
        case .ike:
            propertiesManager.lastIkeConnection = propertiesManager.lastIkeConnection?.withChanged(safeMode: safeMode)
        case .openVpn:
            propertiesManager.lastOpenVpnConnection = propertiesManager.lastOpenVpnConnection?.withChanged(safeMode: safeMode)
        case .wireGuard:
            propertiesManager.lastWireguardConnection = propertiesManager.lastWireguardConnection?.withChanged(safeMode: safeMode)
        case nil:
            break
        }
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
        case .userTorrentNotAllowed, .userBadBehavior:
            log.error("Local agent reported error \(error) that the app does not handle, just disconnecting", category: .localAgent, event: .error)
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
            // because the local agent shared library does not return certificate expired error when connecting with expired certificate 🤷‍♀️
            // instead use this state as the certificate expired error
            didReceiveError(error: LocalAgentError.certificateExpired)
        default:
            break
        }
    }

    func didReceiveFeatures(_ features: VPNConnectionFeatures) {
        didReceiveFeature(netshield: features.netshield)
        didReceiveFeature(vpnAccelerator: features.vpnAccelerator)
        didReceiveFeature(natType: features.natType)
        didReceiveFeature(safeMode: features.safeMode)

        // Try refreshing certificate in case features are different from the ones we have in current certificate
        vpnAuthentication.refreshCertificates(features: features, completion: { [weak self] result in
            switch result {
            case .failure(let error):
                log.error("Failed to refresh certificate in local agent after receiving features",
                          category: .localAgent, event: .error,
                          metadata: ["error": .string(.init(describing: error))])

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

    private func didReceiveFeature(safeMode: Bool?) {
        // ignore nil value received from the Local Agent and also nil value from the provider because it means the feature is not enabled and values should not be used
        guard let currentSafeMode = safeModePropertyProvider.safeMode, let safeMode = safeMode, currentSafeMode != safeMode else {
            return
        }

        log.debug("Safe Mode was set to \(currentSafeMode), changing to \(safeMode) received from local agent", category: .localAgent, event: .stateChange)
        safeModePropertyProvider.safeMode = safeMode
    }
    
    private func didReceiveFeature(vpnAccelerator: Bool) {
        guard propertiesManager.vpnAcceleratorEnabled != vpnAccelerator else {
            return
        }

        log.debug("VPN Accelerator was set to \(propertiesManager.vpnAcceleratorEnabled), changing to \(vpnAccelerator) received from local agent", category: .localAgent, event: .stateChange)
        propertiesManager.vpnAcceleratorEnabled = vpnAccelerator
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
