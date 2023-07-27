//
//  PacketTunnelProvider.swift
//  ProtonVPN - Created on 04/12/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
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

import TunnelKit
import NetworkExtension
import LocalFeatureFlags
import VPNShared
import SwiftyBeaver
import TunnelKitOpenVPN
import TunnelKitOpenVPNAppExtension

// Use the same logging system as TunnelKit underneath.
// If more of our classes (form NEHelper lib) will be added, our custom logging
// system should be used instead.
fileprivate var log = SwiftyBeaver.self

class PacketTunnelProvider: OpenVPNTunnelProvider {

    // This method is overridden to remove username from VPN protocol config. 
    override var protocolConfiguration: NEVPNProtocol {
        guard isEnabled(OpenVPNFeature.macCertificates) else {
            return super.protocolConfiguration
        }

        guard let tunnelProviderProtocol = super.protocolConfiguration as? NETunnelProviderProtocol else {
            log.error("ProtocolConfiguration not set")
            return super.protocolConfiguration
        }

        tunnelProviderProtocol.username = nil
        tunnelProviderProtocol.passwordReference = nil

        return tunnelProviderProtocol
    }
        
    override open func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        if !isEnabled(OpenVPNFeature.macCertificates) {
            let keychain = TunnelKit.Keychain(group: nil)
            do {
                if let user = protocolConfiguration.username {
                    let pass = try keychain.password(for: user, context: AppConstants.NetworkExtensions.openVpn)
                    self.credentials = OpenVPN.Credentials(user, pass)
                    NSLog("PacketTunnelProvider Credentials found") // swiftlint:disable:this no_print
                }
            } catch {
                NSLog("PacketTunnelProvider can't read password from keychain \(error)") // swiftlint:disable:this no_print
            }
        }
        
        super.startTunnel(options: options, completionHandler: completionHandler)
    }
    
}
