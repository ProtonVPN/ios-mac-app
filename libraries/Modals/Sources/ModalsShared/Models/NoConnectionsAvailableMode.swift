//
//  Created on 2025-09-01 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation

import Domain
import Strings

public enum NoConnectionsAvailableMode {
    case noServers
    case loadingError
    case connectionsDisabled
}

public extension NoConnectionsAvailableMode {
    var subtitle: String {
        switch self {
        case .noServers, .connectionsDisabled:
            Localizable.noServersSubtitle
        case .loadingError:
            Localizable.serversLoadingErrorSubtitle
        }
    }

    var helpString: LocalizedStringResource? {
        switch self {
        case .connectionsDisabled:
            .init(stringLiteral: Localizable.noServersHelpString(VPNLink.assignVPNConnections.rawValue))
        case .loadingError:
            .init(stringLiteral: Localizable.noServersContactUs(VPNLink.contact.rawValue))
        case .noServers:
            nil
        }
    }
}
