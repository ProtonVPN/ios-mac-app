//
//  Created on 10/07/2023.
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

import Connection
import Domain
import Localization
import Strings
import VPNAppCore

package struct ConnectionCardModel {
    package init() {}

    package func accessibilityText(for connectionState: ConnectionState, countryName: String) -> String {
        switch connectionState {
        case .disconnected, .disconnecting:
            return Localizable.connectionCardAccessibilityLastConnectedTo(countryName)
        case let .connected(intent, server, _, _):
            if let browsingFrom = LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode),
               let serverNumber = server.logical.serverNumber {
                let vpnProtocol: VpnProtocol = switch intent.protocolConfiguration {
                case .ike:
                    .ike
                case let .wireGuard(settings):
                    .wireGuard(settings.transport)
                }
                // TODO: replace vpnProtocol.apiDescription, VPNAPPL-3550
                return Localizable.connectionCardAccessibilityBrowsingFromFullDetails(
                    browsingFrom,
                    serverNumber,
                    vpnProtocol.apiDescription
                )
            }
            return Localizable.connectionCardAccessibilityBrowsingFrom(countryName)
        case .connecting:
            return Localizable.connectionCardAccessibilityConnectingTo(countryName)
        case .resolving:
            return Localizable.connectionCardAccessibilityLoading
        }
    }

    package func buttonText(for connectionState: ConnectionState) -> String {
        switch connectionState {
        case .disconnected, .disconnecting:
            Localizable.actionConnect
        case .connected:
            Localizable.actionDisconnect
        case .connecting, .resolving:
            Localizable.connectionCardActionCancel
        }
    }
}

private extension Logical {
    var serverNumber: String? {
        name.split(separator: "#").last.map(String.init)
    }
}
