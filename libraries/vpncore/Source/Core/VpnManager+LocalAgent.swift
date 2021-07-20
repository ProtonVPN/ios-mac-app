//
//  VpnManager+LocalAgent.swift
//  Core
//
//  Created by Igor Kulman on 14.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import WireguardSRP

extension VpnManager {
    func connectLocalAgent(data: VpnAuthenticationData?, configuration: VpnManagerConfiguration) {
        localAgent?.disconnect()
        localAgent = data.flatMap({ GoLocalAgent(data: $0, configuration: LocalAgentConfiguration(configuration: configuration)) })
        localAgent?.delegate = self
    }

    func reconnectLocalAgent(data: VpnAuthenticationData) {
        guard let configuration = LocalAgentConfiguration(propertiesManager: propertiesManager, vpnProtocol: currentVpnProtocol) else {
            PMLog.ET("Cannot reconnect to the local agent with missing configuraton")
            return
        }

        localAgent?.disconnect()
        localAgent = GoLocalAgent(data: data, configuration: configuration)
        localAgent?.delegate = self
        localAgent?.connect()
    }

    func refreshCertificateWithError(success: @escaping (VpnAuthenticationData) -> Void) {
        vpnAuthentication.refreshCertificates { [weak self] result in
            switch result {
            case let .success(data):
                success(data)
            case let .failure(error):
                PMLog.ET("Trying to refresh expired or revoked certificate for current connection failed with \(error), showing error and disconnecting")
                self?.alertService?.push(alert: VPNAuthCertificateRefreshErrorAlert())
                self?.disconnect { [weak self] in
                    self?.localAgent?.disconnect()
                }
            }
        }
    }

    func reconnectWithNewKeyAndCertificate() {
        vpnAuthentication.clear()
        refreshCertificateWithError { _ in
            PMLog.D("Generated new keys and got new certificate, asking to reconnect")
            executeOnUIThread {
                NotificationCenter.default.post(name: VpnGateway.needsReconnectNotification, object: nil)
            }
        }
    }

    func disconnectWithAlert(alert: SystemAlert) {
        disconnect { }
        alertService?.push(alert: alert)
    }
}

extension VpnManager: LocalAgentDelegate {
    func didReceiveError(error: LocalAgentError) {
        switch error {
        case .certificateExpired, .certificateNotProvided:
            PMLog.D("Local agent reported expired or missing, trying to refresh and reconnect")
            refreshCertificateWithError { [weak self] data in
                PMLog.D("Reconnecting to local agent with new certificate")
                self?.reconnectLocalAgent(data: data)
            }
        case .badCertificateSignature, .certificateRevoked:
            PMLog.D("Local agent reported invalid certificate signature or revoked certificate, trying to generate new key and certificate and reconnect")
            reconnectWithNewKeyAndCertificate()
        case .keyUsedMultipleTimes:
            PMLog.D("Key used multiple times, trying to generate new key and certificate and reconnect")
            reconnectWithNewKeyAndCertificate()
        case .maxSessionsBasic, .maxSessionsPro, .maxSessionsFree, .maxSessionsPlus, .maxSessionsUnknown, .maxSessionsVisionary:
            disconnect { }
            guard let credentials = try? vpnKeychain.fetch() else {
                PMLog.ET("Cannot show max session alert because getting credentials failed")
                return
            }
            alertService?.push(alert: MaxSessionsAlert(userCurrentCredentials: credentials))
        case .serverError, .restrictedServer:
            PMLog.D("Server error occured, showing the user an alert and disconnecting")
            disconnectWithAlert(alert: VpnServerErrorAlert())
        case .guestSession:
            PMLog.ET("Internal status that should never be seen, check the app implementation")
            disconnect { }
        case .policyViolation2:
            PMLog.D("Disconnecting because of unpaid invoces")
            disconnectWithAlert(alert: DelinquentUserAlert())
        case .policyViolation1:
            disconnectWithAlert(alert: VpnServerSubscriptionErrorAlert())
        case .userTorrentNotAllowed, .userBadBehavior:
            PMLog.ET("Local agent reported error \(error) that the app does not handle, just disconnecting")
            disconnect { }
        }
    }

    func didChangeState(state: LocalAgentState) {
        PMLog.D("Local agent state changed to \(state)")

        switch state {
        case .clientCertificateError:
            // because the local agent shared library does not return certificate expired error when connecting with expired certificate 🤷‍♀️
            // instead use this state as the certificate expired error
            didReceiveError(error: LocalAgentError.certificateExpired)
        default:
            break
        }
    }

    func didReceiveFeature(vpnAccelerator: Bool) {
        guard propertiesManager.vpnAcceleratorEnabled != vpnAccelerator else {
            return
        }

        PMLog.D("VPN Accelerator was set to \(propertiesManager.vpnAcceleratorEnabled), changing to \(vpnAccelerator) received from local agent")
        propertiesManager.vpnAcceleratorEnabled = vpnAccelerator
    }

    func didReceiveFeature(netshield: NetShieldType) {
        let currentNetshield = propertiesManager.netShieldType ?? NetShieldType.off
        guard currentNetshield != netshield else {
            return
        }

        PMLog.D("Netshield was set to \(currentNetshield), changing to \(netshield) received from local agent")
        propertiesManager.netShieldType = netshield
    }
}
