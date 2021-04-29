//
//  LocalAgentState.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import WireguardSRP

enum LocalAgentState {
    case connecting
    case connected
    case softJailed
    case hardJailed
    case connectionError
    case serverCertificateError
    case disconnected
}

extension LocalAgentState {
    static func from(string: String) -> LocalAgentState? {
        switch string {
        case LocalAgentStateConnected:
            return .connected
        case LocalAgentStateConnecting:
            return .connecting
        case LocalAgentStateConnectionError:
            return .connectionError
        case LocalAgentStateDisconnected:
            return .disconnected
        case LocalAgentStateHardJailed:
            return .hardJailed
        case LocalAgentStateServerCertificateError:
            return .serverCertificateError
        case LocalAgentStateSoftJailed:
            return .softJailed
        default:
            PMLog.ET("Trying to parse unknown local agent state \(string)")
            return nil
        }
    }
}
