//
//  Created on 2022-02-24.
//
//  Copyright (c) 2022 Proton AG
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
import vpncore

private extension VpnConnectionInterceptResult.InterceptParameters {
    static func withoutUsingKillSwitch(with connectionProtocol: ConnectionProtocol) -> Self {
        Self(newProtocol: connectionProtocol, smartProtocolWithoutWireGuard: false, disableKillSwitch: true)
    }

    static var usingSmartProtocolWithoutWireGuard: Self {
        Self(newProtocol: .smartProtocol, smartProtocolWithoutWireGuard: true, disableKillSwitch: false)
    }

    static var switchingToOpenVpnTcp: Self {
        Self(newProtocol: .vpnProtocol(.openVpn(.tcp)), smartProtocolWithoutWireGuard: false, disableKillSwitch: false)
    }
}

class ConnectionIntercepts {
    typealias Factory = CoreAlertServiceFactory

    private let factory: Factory

    private lazy var alertService = factory.makeCoreAlertService()

    public private(set) var intercepts: [VpnConnectionInterceptPolicyItem] = []

    init(factory: Factory) {
        self.factory = factory
    }
}
