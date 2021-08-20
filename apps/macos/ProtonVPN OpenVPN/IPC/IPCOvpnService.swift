//
//  iPCOvpnService.swift
//  ProtonVPN OpenVPN
//
//  Created by Jaroslav on 2021-08-09.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import TunnelKit

class IPCOvpnService: XPCBaseService {
    
}


extension IPCOvpnService { // ProviderCommunication
    
    override func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        let keychain = Keychain(group: nil)
        do {
            let currentPassword = try? keychain.password(for: username)
            guard currentPassword != password else {
                completionHandler(true)
                return
            }
            
            try keychain.set(password: password, for: username)
            log("PacketTunnelProvider new password saved")
            completionHandler(true)
            
        } catch {
            log("PacketTunnelProvider can't write password to keychain: \(error)")
            completionHandler(false)
        }
    }
}
