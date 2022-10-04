//
//  IPCWGConnection.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-07-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import os.log

/// App -> Provider IPC
@objc protocol ProviderCommunication {
    /// Used by both extensions to get log data
    func getLogs(_ completionHandler: @escaping (Data?) -> Void)
    /// Used by OpenVPN extension to set connection credentials.
    func setCredentials(username: String,
                        password: String,
                        completionHandler: @escaping (Bool) -> Void)
    /// Used by WireGuard extension to set the connection configuration, including creds.
    func setConfigData(_ data: Data,
                       completionHandler: @escaping (Bool) -> Void)
}

/// Provider -> App IPC
@objc protocol AppCommunication {
}
