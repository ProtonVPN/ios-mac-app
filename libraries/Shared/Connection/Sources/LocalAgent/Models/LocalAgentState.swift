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
        switch string {
        case localAgentConsts.stateConnected:
            return .connected
        case localAgentConsts.stateConnecting:
            return .connecting
        case localAgentConsts.stateConnectionError:
            return .connectionError
        case localAgentConsts.stateDisconnected:
            return .disconnected
        case localAgentConsts.stateHardJailed:
            return .hardJailed
        case localAgentConsts.stateServerUnreachable:
            return .serverUnreachable
        case localAgentConsts.stateServerCertificateError, localAgentConsts.stateClientCertificateUnknownCA:
            return .serverCertificateError
        case localAgentConsts.stateClientCertificateExpiredError:
            return .clientCertificateError
        case localAgentConsts.stateSoftJailed:
            return .softJailed
        default:
            log.error("Trying to parse unknown local agent state \(string)", category: .localAgent)
            return .invalid
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
