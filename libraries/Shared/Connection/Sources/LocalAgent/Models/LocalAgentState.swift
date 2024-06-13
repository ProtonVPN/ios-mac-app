//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation
import CasePaths
import GoLibs
import let ConnectionFoundations.log

@CasePathable
public enum LocalAgentState: Sendable {
    case connecting
    case connected
    case softJailed
    case hardJailed
    case connectionError
    case serverUnreachable
    case serverCertificateError
    case clientCertificateError
    case disconnected

    case invalid
}

extension LocalAgentState {

    // swiftlint:disable cyclomatic_complexity
    static func from(string: String) -> LocalAgentState {
        guard let consts = LocalAgentConstants() else {
            log.error("Failed to create local agent constants", category: .localAgent)
            return .invalid
        }

        switch string {
        case consts.stateConnected:
            return .connected
        case consts.stateConnecting:
            return .connecting
        case consts.stateConnectionError:
            return .connectionError
        case consts.stateDisconnected:
            return .disconnected
        case consts.stateHardJailed:
            return .hardJailed
        case consts.stateServerUnreachable:
            return .serverUnreachable
        case consts.stateServerCertificateError, consts.stateClientCertificateUnknownCA:
            return .serverCertificateError
        case consts.stateClientCertificateExpiredError:
            return .clientCertificateError
        case consts.stateSoftJailed:
            return .softJailed
        default:
            log.error("Trying to parse unknown local agent state \(string)", category: .localAgent)
            return .invalid
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
