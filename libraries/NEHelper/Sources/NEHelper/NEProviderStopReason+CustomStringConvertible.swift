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

extension NEProviderStopReason: CustomStringConvertible {

    public var description: String {
        switch self {
        case .none:
            return "none (\(self.rawValue))"
        case .userInitiated:
            return "userInitiated (\(self.rawValue))"
        case .providerFailed:
            return "providerFailed (\(self.rawValue))"
        case .noNetworkAvailable:
            return "noNetworkAvailable (\(self.rawValue))"
        case .unrecoverableNetworkChange:
            return "unrecoverableNetworkChange (\(self.rawValue))"
        case .providerDisabled:
            return "providerDisabled (\(self.rawValue))"
        case .authenticationCanceled:
            return "authenticationCanceled (\(self.rawValue))"
        case .configurationFailed:
            return "configurationFailed (\(self.rawValue))"
        case .idleTimeout:
            return "idleTimeout (\(self.rawValue))"
        case .configurationDisabled:
            return "configurationDisabled (\(self.rawValue))"
        case .configurationRemoved:
            return "configurationRemoved (\(self.rawValue))"
        case .superceded:
            return "superceded (\(self.rawValue))"
        case .userLogout:
            return "userLogout (\(self.rawValue))"
        case .userSwitch:
            return "userSwitch (\(self.rawValue))"
        case .connectionFailed:
            return "connectionFailed (\(self.rawValue))"
        case .sleep:
            return "sleep (\(self.rawValue))"
        case .appUpdate:
            return "appUpdate (\(self.rawValue))"
        @unknown default:
            return "unknown (\(self.rawValue))"
        }
    }

}
