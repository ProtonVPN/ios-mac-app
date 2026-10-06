//
//  Created on 2026-03-04 by Pawel Jurczyk.
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

import Combine
import Dependencies
import Domain
import LegacyCommon
import Persistence

package struct ProtocolFilters {
    // MARK: - Server and Group query filters

    @Dependency(\.propertiesManager) private var propertiesManager

    package init() {}

    private var currentConnectionProtocol: ConnectionProtocol {
        propertiesManager.connectionProtocol
    }

    private var supportedProtocols: [VpnProtocol] {
        switch currentConnectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            [vpnProtocol]
        case .smartProtocol:
            propertiesManager.smartProtocolConfig.supportedProtocols
        }
    }

    private var requiredProtocolSupport: ProtocolSupport {
        supportedProtocols.reduce(.zero) { $0.union($1.protocolSupport) }
    }

    package var supportedProtocolsFilter: VPNServerFilter {
        .supports(protocol: requiredProtocolSupport)
    }

    /// Sends the protocols a server must support, first right away and then each time the user's choice changes it.
    ///
    /// PropertiesManager posts a `vpnProtocol` or `smartProtocol` event when the user picks a protocol. Switching from
    /// Smart to a single protocol posts both, so the publisher skips values equal to the one it sent last.
    package var requiredProtocolSupportPublisher: some Publisher<ProtocolSupport, Never> {
        AppEvent.vpnProtocol.publisher
            .merge(with: AppEvent.smartProtocol.publisher)
            .map { _ in requiredProtocolSupport }
            .prepend(requiredProtocolSupport)
            .removeDuplicates()
    }
}
