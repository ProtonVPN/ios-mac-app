//
//  OVPNiOSCredentialsConfigurator.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import LegacyCommon
import TunnelKit
import LocalFeatureFlags
import VPNShared

final class OVPNiOSCredentialsConfigurator: VpnCredentialsConfigurator {

    private let vpnAuthentication: VpnAuthentication

    init(vpnAuthentication: VpnAuthentication) {
        self.vpnAuthentication = vpnAuthentication
    }

    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        guard isEnabled(OpenVPNFeature.iosCertificates) else { // Old flow
            protocolConfig.username = configuration.username
            let storage = TunnelKit.Keychain(group: AppConstants.AppGroups.main)
            try? storage.set(password: configuration.password, for: configuration.username, context: AppConstants.NetworkExtensions.openVpn)
            completionHandler(protocolConfig)
            return
        }

        // Username is needed to detect connections started from another user (see
        // `AppSessionManager.resolveActiveSession`). OpenVPN NE deletes this field before passing
        // it down to TunnelKit (this is not back propagated to the app though, so we can still use
        // it here).
        protocolConfig.username = configuration.username

        // Make sure clients private key is in the keychain. It is necessary to ask
        // API for a new certificate before connection can be established.
        _ = self.vpnAuthentication.loadClientPrivateKey()

        completionHandler(protocolConfig)
    }
    
}
