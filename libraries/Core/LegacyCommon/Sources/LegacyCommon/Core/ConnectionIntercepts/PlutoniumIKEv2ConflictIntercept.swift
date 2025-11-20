//
//  Created on 2025-08-14 by Pawel Jurczyk.
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

import Dependencies
import Sharing

import Domain
import VPNAppCore

#if canImport(AppKit)

    struct PlutoniumIKEv2ConflictIntercept: VpnConnectionInterceptPolicyItem {
        typealias Factory = CoreAlertServiceFactory

        let alertService: CoreAlertService
        @Dependency(\.propertiesManager) private var propertiesManager

        @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle

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
            isKillSwitchOn _: Bool,
            completion: @escaping (VpnConnectionInterceptResult) -> Void
        ) {
            if case .enabled = feature,
               connectionProtocol == .vpnProtocol(.ike),
               let request = propertiesManager.lastConnectionRequest {
                let alert = IKEv2PlutoniumConflictAlert(profileName: request.profileName, disablePlutoniumHandler: {
                    $feature.withLock {
                        $0.disable()
                    }
                    completion(.allow)
                })
                alertService.push(alert: alert)
            } else {
                completion(.allow)
            }
        }
    }

#endif
