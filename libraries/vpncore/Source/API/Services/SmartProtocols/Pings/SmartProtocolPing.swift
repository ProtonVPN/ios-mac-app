//
//  SmartProtocolPing.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

protocol SmartProtocolPing {
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void)
}
