//
//  VpnFeatureChangeState.swift
//  Core
//
//  Created by Igor Kulman on 05.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum VpnFeatureChangeState {
    case withConnectionUpdate
    case withReconnect
    case immediately
}

extension VpnFeatureChangeState {
    public init(state: VpnState, vpnProtocol: VpnProtocol?) {
        switch state {
        case .connected where vpnProtocol?.authenticationType == .certificate:
            self = .withConnectionUpdate
        case .connected, .connecting:
            self = .withReconnect
        default:
            self = .immediately
        }
    }
}
