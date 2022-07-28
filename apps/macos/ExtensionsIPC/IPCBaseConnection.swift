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
    func getLogs(_ completionHandler: @escaping (Data?) -> Void)
    func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void)
}

/// Provider -> App IPC
@objc protocol AppCommunication {
}
