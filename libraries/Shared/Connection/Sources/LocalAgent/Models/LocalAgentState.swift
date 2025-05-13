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
import let CoreConnection.log

@CasePathable
public enum LocalAgentState: Sendable {
    case connecting
    case connected
    case disconnected

    case softJailed
    /// This state is accompanied by a more specific error, which will *always* be reported via an error event.
    /// It doesn't always warrant an explicit action/response - determine this by checking the more specific `LocalAgentError`.
    case hardJailed
    /// This state is set when the LA server reports an error that is not known by the Go client
    case connectionError
    // LA will keep retrying to connect
    case serverUnreachable
    // We have to request a new certificate, and create a new local agent connection with it
    case serverCertificateError
    // We have to request a new certificate, and create a new local agent connection with it
    case clientCertificateUnknownCA
    // We have to request a new certificate, and create a new local agent connection with it
    case clientCertificateExpired
    /// This is an unknown/future state. Check the Go library and add it here.
    case invalid
}

extension LocalAgentState {

    // swiftlint:disable cyclomatic_complexity
    /// For more information, check [Shared VPN Libraries](https://github.com/ProtonVPN/go-vpn-lib/tree/master/localAgent)
    static func from(string: String) -> LocalAgentState {
        switch string {
        case localAgentConsts.stateConnected:
            return .connected
        case localAgentConsts.stateConnecting:
            return .connecting
        case localAgentConsts.stateWaitingForNetwork:
            return .connecting
        case localAgentConsts.stateConnectionError:
            return .connectionError
        case localAgentConsts.stateDisconnected:
            return .disconnected
        case localAgentConsts.stateHardJailed:
            return .hardJailed
        case localAgentConsts.stateServerUnreachable:
            return .serverUnreachable
        case localAgentConsts.stateServerCertificateError:
            return .serverCertificateError
        case localAgentConsts.stateClientCertificateUnknownCA:
            return .clientCertificateUnknownCA
        case localAgentConsts.stateClientCertificateExpiredError:
            return .clientCertificateExpired
        case localAgentConsts.stateSoftJailed:
            return .softJailed
        default:
            log.error("Trying to parse unknown local agent state \(string)", category: .localAgent)
            assertionFailure("Unknown local agent state: \(string)")
            return .invalid
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
