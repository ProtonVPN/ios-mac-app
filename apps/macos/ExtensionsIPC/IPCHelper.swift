//
//  IPCHelper.swift
//  macOS
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class IPCHelper {
    
    /**
     The NetworkExtension framework registers a Mach service with the name in the system extension's NEMachServiceName Info.plist key.
     The Mach service name must be prefixed with one of the app groups in the system extension's com.apple.security.application-groups entitlement.
     Any process in the same app group can use the Mach service to communicate with the system extension.
     */
    static func extensionMachServiceName(from bundle: Bundle) -> String {
        guard let networkExtensionKeys = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
              let machServiceName = networkExtensionKeys["NEMachServiceName"] as? String else {
            fatalError("Mach service name is missing from the Info.plist")
        }
        return machServiceName
    }
    
}
