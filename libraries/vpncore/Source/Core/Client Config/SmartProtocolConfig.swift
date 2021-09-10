//
//  SmartProtocolConfig.swift
//  Core
//
//  Created by Igor Kulman on 11.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public struct SmartProtocolConfig: Codable {
    public let openVPN: Bool
    public let iKEv2: Bool
    public let wireGuard: Bool

    enum CodingKeys: String, CodingKey {
        case openVPN
        case iKEv2 = "IKEv2"
        case wireGuard
    }

    public init(openVPN: Bool, iKEv2: Bool, wireGuard: Bool) {
        self.openVPN = openVPN
        self.iKEv2 = iKEv2
        self.wireGuard = wireGuard
    }

    public init() {
        self.init(openVPN: true, iKEv2: true, wireGuard: true)
    }
}
