//
//  XPCWGService.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class IPCWGService: XPCBaseService {
    
}


extension IPCWGService { // ProviderCommunication
    
    override func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        let wgConfig = password
        log("Will save wg config: \(wgConfig)")
        if Keychain.saveWgConfig(value: wgConfig) {
            log("New config saved.")
            completionHandler(true)
        } else {
            log("New config save error.")
            completionHandler(false)
        }
    }
}
