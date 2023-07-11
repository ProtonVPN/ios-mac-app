//
//  Created on 05/07/2023.
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
import VPNShared

public enum ConnectionProtocol: Equatable, Hashable, CaseIterable, Sendable {
    case vpnProtocol(VpnProtocol)
    case smartProtocol

    public var vpnProtocol: VpnProtocol? {
        guard case let .vpnProtocol(vpnProtocol) = self else {
            return nil
        }
        return vpnProtocol
    }

    public var shouldBeEnabledByDefault: Bool {
        guard self == .smartProtocol else { return false }
#if os(macOS)
        // On MacOS, the user must approve system extensions before Smart Protocol can be used
        return false
#else
        return true
#endif
    }

#if os(macOS)
    public var requiresSystemExtension: Bool {
        guard self != .smartProtocol else {
            return true
        }
        return vpnProtocol?.requiresSystemExtension == true
    }
#endif

    public static let allCases: [ConnectionProtocol] = [.smartProtocol] +
    VpnProtocol.allCases.map(Self.vpnProtocol)
}

#if os(macOS)
extension VpnProtocol {
    public var requiresSystemExtension: Bool {
        switch self {
        case .openVpn, .wireGuard:
            return true
        default:
            return false
        }
    }
}
#endif
