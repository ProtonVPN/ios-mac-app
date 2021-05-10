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

class PacketTunnelProvider: OpenVPNTunnelProvider {
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        if let credentials = try? JSONDecoder().decode(OpenVPN.Credentials.self, from: messageData) {
            
            let keychain = Keychain(group: nil)
            do {
                let currentPassword = try? keychain.password(for: credentials.username)
                guard currentPassword != credentials.password else {
                    completionHandler?(nil)
                    return
                }
                
                try keychain.set(password: credentials.password, for: credentials.username)
                NSLog("PacketTunnelProvider new password saved")
                let ref = try keychain.passwordReference(for: credentials.username)
                
                self.credentials = credentials
                self.session?.credentials = credentials
                
                self.startTunnel(completionHandler: {error in
                    NSLog("PacketTunnelProvider tunnel start finished \(String(describing: error))")
                })
                
                completionHandler?(ref)
                
            } catch {
                NSLog("PacketTunnelProvider can't write password to keychain: \(error)")
            }
            return
        }
        super.handleAppMessage(messageData, completionHandler: completionHandler)
    }
    
    open override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let keychain = Keychain(group: nil)
        do {
            if let user = protocolConfiguration.username {
                let pass = try keychain.password(for: user)
                self.credentials = OpenVPN.Credentials(user, pass)
                NSLog("PacketTunnelProvider Credentials found")
            }
        } catch {
            NSLog("PacketTunnelProvider can't read password from keychain \(error)")
        }
        
        super.startTunnel(options: options, completionHandler: completionHandler)
    }
    
}
