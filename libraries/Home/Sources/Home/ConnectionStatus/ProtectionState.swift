//
//  Created on 09/06/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Strings
import VPNShared

public enum ProtectionState: Equatable {
    case protected(netShield: NetShieldModel)
    case unprotected(country: String, ip: String)
    case protecting(country: String, ip: String)
}

extension VPNConnectionStatus {
    var protectionState: ProtectionState {
        switch self {
        case .disconnected:
            return .unprotected(country: "Country", ip: "127.0.0.1") // todo: get real values
        case .connected:
            return .protected(netShield: .random) // todo:
        case .connecting, .loadingConnectionInfo:
            return .protecting(country: "Country", ip: "127.0.0.2") // todo:
        case .disconnecting:
            return .unprotected(country: "Country", ip: "127.0.0.1") // todo:
        }
    }
}
