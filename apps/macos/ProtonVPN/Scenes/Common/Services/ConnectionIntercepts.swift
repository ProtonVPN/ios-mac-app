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

/// WG + KS is not working on Catalina. Let's prevent users from having trouble by prompting them to disable either Wireguard or Kill Switch.
/// If they're using a smart protocol, elide Wireguard from the array of protocols chosen.
struct CatalinaKSIntercept: VpnConnectionInterceptPolicyItem {
    let alertService: CoreAlertService

    func shouldIntercept(_ connectionProtocol: ConnectionProtocol, isKillSwitchOn: Bool, completion: @escaping (VpnConnectionInterceptResult) -> Void) {
        guard isKillSwitchOn, #available(macOS 10.15, *) else {
            completion(.allow)
            return
        }
        if #available(macOS 11, *) {
            completion(.allow)
            return
        }

        switch connectionProtocol {
        // If WireGuard is selected, let's ask user to change it
        case .vpnProtocol(.wireGuard):
            log.debug("WireGuard + KillSwitch on Catalina detected. Asking user to change one or another.", category: .connectionConnect, event: .scan)

            DispatchQueue.global(qos: .userInteractive).async {
                alertService.push(alert: WireguardKSOnCatalinaAlert(killSwitchOffHandler: {
                    completion(.intercept(.withoutUsingKillSwitch(with: connectionProtocol)))
                }, openVpnHandler: {
                    completion(.intercept(.switchingToOpenVpnTcp))
                }))
            }
        // If SmartProtocol is used, let's make it smart enough to not select WireGuard if we know it won't work
        case .smartProtocol:
            log.debug("SmartProtocol + KillSwitch on Catalina detected. Disabling WireGuard in SmartProtocol.", category: .connectionConnect, event: .scan)
            completion(.intercept(.usingSmartProtocolWithoutWireGuard))
        default:
            completion(.allow)
        }
    }
}

class ConnectionIntercepts {
    typealias Factory = CoreAlertServiceFactory

    private let factory: Factory

    private lazy var alertService = factory.makeCoreAlertService()

    public private(set) var intercepts: [VpnConnectionInterceptPolicyItem] = []

    init(factory: Factory) {
        self.factory = factory

        self.intercepts = [
            CatalinaKSIntercept(alertService: alertService),
        ]
    }
}
