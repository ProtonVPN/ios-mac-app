//
//  Created on 2024-03-21.
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
import NetworkExtension

extension NEProviderStopReason: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "none (\(rawValue))"
        case .userInitiated:
            return "userInitiated (\(rawValue))"
        case .providerFailed:
            return "providerFailed (\(rawValue))"
        case .noNetworkAvailable:
            return "noNetworkAvailable (\(rawValue))"
        case .unrecoverableNetworkChange:
            return "unrecoverableNetworkChange (\(rawValue))"
        case .providerDisabled:
            return "providerDisabled (\(rawValue))"
        case .authenticationCanceled:
            return "authenticationCanceled (\(rawValue))"
        case .configurationFailed:
            return "configurationFailed (\(rawValue))"
        case .idleTimeout:
            return "idleTimeout (\(rawValue))"
        case .configurationDisabled:
            return "configurationDisabled (\(rawValue))"
        case .configurationRemoved:
            return "configurationRemoved (\(rawValue))"
        case .superceded:
            return "superceded (\(rawValue))"
        case .userLogout:
            return "userLogout (\(rawValue))"
        case .userSwitch:
            return "userSwitch (\(rawValue))"
        case .connectionFailed:
            return "connectionFailed (\(rawValue))"
        case .sleep:
            return "sleep (\(rawValue))"
        case .appUpdate:
            return "appUpdate (\(rawValue))"
        case .internalError:
            return "internalError (\(rawValue))"
        @unknown default:
            return "unknown (\(rawValue))"
        }
    }
}
