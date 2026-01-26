//
//  VpnProtocol.swift
//  ProtonVPN - Created on 13.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Domain
import Ergonomics
import Foundation
import Strings
import VPNShared

extension VpnProtocol: @retroactive DefaultableProperty {
    public init() {
        self = .defaultValue
    }
}

public extension VpnProtocol { // Authentication
    enum AuthenticationType {
        case credentials
        case certificate
    }

    var authenticationType: AuthenticationType {
        switch self {
        case .ike: .credentials
        case .wireGuard: .certificate
        }
    }
}
