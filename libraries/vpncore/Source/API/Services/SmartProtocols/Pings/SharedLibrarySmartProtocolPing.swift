//
//  SharedLibraryPing.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import WireguardSRP

final class SharedLibrarySmartProtocolPing: SmartProtocolPing {
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        PMLog.D("Checking \(protocolName) availability for \(server.entryIp) on port \(port)")

        guard let key = server.x25519PublicKey else {
            PMLog.D("Cannot check \(protocolName) availability for \(server.entryIp) on port \(port) because of missing public key")
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSError?
            var ret: ObjCBool = false
            let result = VpnPingPingSync(server.entryIp, port, key, Int(timeout), &ret, &error)

            if let error = error {
                PMLog.D("\(protocolName) NOT available for \(server.entryIp) on port \(port) (Error: \(error)")
                completion(false)
                return
            }

            PMLog.D("\(protocolName)\(result ? "" : " NOT") available for \(server.entryIp) on port \(port)")
            completion(result)
        }
    }
}
