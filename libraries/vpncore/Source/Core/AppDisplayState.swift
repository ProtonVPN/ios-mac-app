//
//  AppDisplayState.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public enum AppDisplayState {
    case connected
    case connecting
    case loadingConnectionInfo
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
