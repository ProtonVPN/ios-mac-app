//
//  VpnFeatureChangeState.swift
//  Core
//
//  Created by Igor Kulman on 05.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum VpnFeatureChangeState {
    case withLocalAgent
    case withReconnect
    case immediatelly
}

extension VpnFeatureChangeState {
    public init(status: ConnectionStatus, vpnProtocol: VpnProtocol?) {
        switch status {
        case .connected where vpnProtocol?.authenticationType == .certificate:
            self = .withLocalAgent
        case .connected, .connecting:
            self = .withReconnect
        default:
            self = .immediatelly
        }
    }
}
