//
//  Created on 19/05/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain
import Foundation

public extension LocalAgent {
    enum Error: Swift.Error {
        case localAgentSettingPolicyRefused(SettingType)
        case certificateRefreshFatalError
    }
}

extension LocalAgent.Error: Codable, Equatable, Sendable {}

extension LocalAgent.Error: ReconstructableError {
    public init?(charCode: FourCharCode) {
        switch charCode {
        case "LACF": self = .certificateRefreshFatalError
        case "PRNS": self = .localAgentSettingPolicyRefused(.netshieldLevel)
        case "PRBO": self = .localAgentSettingPolicyRefused(.bouncing)
        case "PRPF": self = .localAgentSettingPolicyRefused(.portForwarding)
        case "PRST": self = .localAgentSettingPolicyRefused(.splitTcp)
        case "PRSM": self = .localAgentSettingPolicyRefused(.safeMode)
        case "PRNT": self = .localAgentSettingPolicyRefused(.randomNat)
        default: return nil
        }
    }
}

extension LocalAgent.Error: ProtonVPNError {
    public static let errorDomain = "LocalAgentErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .certificateRefreshFatalError: "LACF"
        case .localAgentSettingPolicyRefused(.netshieldLevel): "PRNS"
        case .localAgentSettingPolicyRefused(.bouncing): "PRBO"
        case .localAgentSettingPolicyRefused(.portForwarding): "PRPF"
        case .localAgentSettingPolicyRefused(.splitTcp): "PRST"
        case .localAgentSettingPolicyRefused(.safeMode): "PRSM"
        case .localAgentSettingPolicyRefused(.randomNat): "PRNT"
        }
    }
}
