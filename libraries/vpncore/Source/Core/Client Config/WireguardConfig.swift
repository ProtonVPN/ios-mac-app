//
//  WireguardConfig.swift
//  Core
//
//  Created by Igor Kulman on 11.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public struct WireguardConfig: Codable {
    public let defaultPorts: [Int]
    public var dns: String {
        return "10.2.0.1"
    }
    public var address: String {
        return "10.2.0.2/32"
    }
    public var allowedIPs: String {
        return "0.0.0.0/0"
    }

    init(defaultPorts: [Int] = [51820]) {
        self.defaultPorts = defaultPorts
    }
}
