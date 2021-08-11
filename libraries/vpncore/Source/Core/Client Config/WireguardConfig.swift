//
//  WireguardConfig.swift
//  Core
//
//  Created by Igor Kulman on 11.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public struct WireguardConfig: Codable {
    let defaultPorts: [Int]

    init(defaultPorts: [Int] = [51820]) {
        self.defaultPorts = defaultPorts
    }
}
