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
