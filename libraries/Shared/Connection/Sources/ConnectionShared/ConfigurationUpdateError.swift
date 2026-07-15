//
//  Created on 29.06.2026 by John Biggs.
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

/// The different error cases for configuration updates. These are sent from ProTUN over the error RawChannel.
///
/// - Important: These errors get reported *regardless of the request UUID matching*, and can leave the app stuck
///              in a "resolving" state until the next configuration update request. Make sure the update has
///              actually failed to apply, i.e., that the failure happened before ProTUN was reconfigured.
public enum ConfigurationUpdateError: FourCharCode, ProtonVPNError {
    public static let errorDomain = "ConfigurationUpdateErrorDomain"

    case badConfiguration = "CUBC"
    case badEncoding = "CUBE"
    case noConnection = "CUNC"
    case timeout = "CUTO"
}
