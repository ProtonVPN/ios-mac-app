//
//  AppDisplayState.swift
//  Core
//
//  Created by Igor Kulman on 09.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum AppDisplayState {
    case connected
    case connecting
    case fetchingInfo
    case disconnecting
    case disconnected
}

extension AppState {
    func asDisplayState() -> AppDisplayState {
        switch self {
        case .connected:
            return .connected
        case .preparingConnection, .connecting:
            return .connecting
        case .disconnecting:
            return .disconnecting
        case .error, .disconnected, .aborted:
            return .disconnected
        }
    }
}
