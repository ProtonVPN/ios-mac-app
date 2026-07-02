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
    enum Error: FourCharCode, Equatable, ProtonVPNError {
        public static let errorDomain = "LocalAgentExtensionErrorDomain"

        // Policy violation (refused settings)
        case unknownSettingRefused = "LAUS"
        case netShieldSettingRefused = "LANS"
        case bouncingSettingRefused = "LABO"
        case portForwardingSettingRefused = "LAPF"
        case splitTcpSettingRefused = "LAST"
        case safeModeSettingRefused = "LASM"
        case randomNatSettingRefused = "LARN"

        /// The server requires a more recent 2FA, for an unspecified reason.
        case authenticationRequired = "LA2R"
        /// The server requires a more recent 2FA, 2FA validity has expired.
        /// This is more specific than `authenticationRequired` to give the user an explanation, but the behavior is
        /// exactly the same.
        case authenticationExpired = "LA2E"
        /// The server requires a more recent 2FA, as it’s a new connection or the client address has roamed.
        /// From the client perspective, this can be handled as `authenticationRequired` (if the client supports it),
        /// or ad-interim by asking the user to provide a 2FA via the browser.
        case authenticationLocationChanged = "LA2L"

        public var settingWasRefused: Bool {
            switch self {
            case .bouncingSettingRefused, .netShieldSettingRefused,
                 .portForwardingSettingRefused, .randomNatSettingRefused,
                 .safeModeSettingRefused, .splitTcpSettingRefused,
                 .unknownSettingRefused:
                true
            default:
                false
            }
        }

        public var twoFactorRequired: Bool {
            switch self {
            case .authenticationRequired, .authenticationExpired, .authenticationLocationChanged:
                true
            default:
                false
            }
        }
    }
}

public enum ExtensionTunnelError: FourCharCode, ProtonVPNError {
    public static let errorDomain = "ExtensionTunnelErrorDomain"

    case certificateRefreshFatalError = "XLCF"
    case unknownProTUNError = "PTUK"
}
