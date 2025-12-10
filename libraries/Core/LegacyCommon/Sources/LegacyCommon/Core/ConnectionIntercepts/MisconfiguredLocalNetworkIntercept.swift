//
//  Created on 09.08.23.
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

import Dependencies
import Foundation
import Network
import VPNNetworking

import Domain
import VPNAppCore

/// Misconfigured Local Networks
///
/// Networks come in all shapes and sizes. All local networks *should* comply with RFC1918 for distributing local IP
/// addresses, but not all of them do. In cases where they don't, the OS can decide that, since the IP "looks" like a
/// local IP according to the interface, it should send the traffic over the local network unencrypted. This is
/// obviously bad, so we scan the interfaces of the device to see if any aren't compliant with RFC1918 (which defines
/// which IPs are "LAN" IPs) or RFC3927 (which defines "peer-to-peer" IPs). If they aren't, display a warning to the
/// user encouraging them to use Kill Switch, which will route *all* traffic over the VPN, regardless of whether it looks
/// like it's destined for the local network according to the interface configuration.
struct MisconfiguredLocalNetworkIntercept: VpnConnectionInterceptPolicyItem {
    typealias Factory = CoreAlertServiceFactory

    let alertService: CoreAlertService
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.networkInterfacePropertiesProvider) var interfacePropertiesProvider

    init(
        alertService: CoreAlertService
    ) {
        self.alertService = alertService
    }

    init(factory: Factory) {
        self.init(
            alertService: factory.makeCoreAlertService()
        )
    }

    public func shouldIntercept(
        _ connectionProtocol: ConnectionProtocol,
        isKillSwitchOn: Bool,
        completion: @escaping (VpnConnectionInterceptResult) -> Void
    ) {
        guard propertiesManager.featureFlags.unsafeLanWarnings else {
            completion(.allow)
            return
        }

        guard !isKillSwitchOn else {
            completion(.allow) // kill switch mitigates this issue by using the tunnel for everything
            return
        }

        var badInterface: NetworkInterface?
        do {
            let interfaces = try interfacePropertiesProvider.withNetworkInterfaceInfo()
            badInterface = interfaces.first(where: \.hasBadRanges)
        } catch {
            log.error("Couldn't fetch interface information: \(error)")
        }

        guard let badInterface else {
            completion(.allow)
            return
        }

        alertService.push(alert: ConnectingWithBadLANAlert(
            badIpAndPrefix: badInterface.ipv4SubnetDescription,
            badInterfaceName: badInterface.name,
            killSwitchOnHandler: {
                completion(.intercept(.init(
                    newProtocol: connectionProtocol,
                    smartProtocolWithoutWireGuard: false,
                    newKillSwitch: true
                )))
            },
            connectAnywayHandler: {
                completion(.allow)
            }
        ))
    }
}
