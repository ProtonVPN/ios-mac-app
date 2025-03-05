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

import Domain
import Strings

import Localization
import VPNAppCore

package struct ConnectionCardModel {
    package init() {}

    package func accessibilityText(for vpnConnectionStatus: VPNConnectionStatus, countryName: String) -> String {
        switch vpnConnectionStatus {
        case .disconnected, .disconnecting:
            return Localizable.connectionCardAccessibilityLastConnectedTo(countryName)
        case .connected(_, let actual):
            if let parameters = actual?.accessibilityParameters {
                return Localizable.connectionCardAccessibilityBrowsingFromFullDetails(
                    parameters.browsingFrom,
                    parameters.serverNumber,
                    parameters.protocolDescription
                )
            }
            return Localizable.connectionCardAccessibilityBrowsingFrom(countryName)
        case .connecting:
            return Localizable.connectionCardAccessibilityConnectingTo(countryName)
        case .resolving:
            return Localizable.connectionCardAccessibilityLoading
        }
    }

    package func buttonText(for vpnConnectionStatus: VPNConnectionStatus) -> String {
        switch vpnConnectionStatus {
        case .disconnected:
            return Localizable.actionConnect
        case .connected:
            return Localizable.actionDisconnect
        case .connecting, .disconnecting, .resolving:
            return Localizable.connectionCardActionCancel
        }
    }
}

private extension VPNConnectionActual {
    var accessibilityParameters: (browsingFrom: String, serverNumber: String, protocolDescription: String)? {
        if let browsingFrom, let serverNumber = server.logical.serverNumber {
            return (browsingFrom, serverNumber, vpnProtocol.apiDescription)
        }
        return nil
    }

    private var browsingFrom: String? {
        LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode)
    }
}

private extension Logical {
    var serverNumber: String? {
        name.split(separator: "#").last.map(String.init)
    }
}
