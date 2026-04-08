//
//  Created on 22/07/2025 by Max Kupetskyi.
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
import Domain
import Foundation
import LegacyCommon
import Sharing
import Strings
import Theme
import VPNAppCore

final class PortForwardingDropdownPresenter: QuickSettingDropdownPresenter {
    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & VpnGatewayFactory & VpnManagerFactory

    private let factory: Factory

    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    override var learnLink: String {
        VPNLink.portForwardingSupport.urlString
    }

    override var title: String {
        Localizable.portForwarding
    }

    override var descriptionText: String {
        Localizable.quickSettingsPortForwardingDescription
    }

    override var noteText: String {
        ""
    }

    override var alert: UpsellAlert {
        PortForwardingUpsellAlert()
    }

    // MARK: - Init

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
    }

    override var options: [QuickSettingDropdownOption] {
        [portForwardingOff, portForwardingOn]
    }

    // MARK: - Private

    private var portForwardingOff: QuickSettingDropdownOption {
        let active = portForwardingPropertyProvider.getPortForwarding() ?? false
        let text = Localizable.portForwarding + " " + Localizable.switchSideButtonOff.capitalized
        let icon = Theme.Asset.Icons.arrowUpBounceLeft.swiftUIImage
        return QuickSettingDropdownOption(text, icon: icon, active: !active, selectCallback: { [weak self] dismissCallback in
            guard let self else { return }
            portForwardingPropertyProvider.setPortForwarding(false)
            switch vpnManager.currentVpnProtocol {
            case .wireGuard:
                log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                vpnManager.set(portForwarding: false)
                vpnManager.stopNATPortMappingService()

            case .ike:
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnGateway.retryConnection()
                }

            // other protocols are not supported
            default:
                assertionFailure("not supported protocol in port forwarding presenter")
            }

            dismissCallback()
        })
    }

    private var portForwardingOn: QuickSettingDropdownOption {
        let active = portForwardingPropertyProvider.getPortForwarding() ?? false
        let text = Localizable.portForwarding + " " + Localizable.switchSideButtonOn.capitalized
        let icon = Theme.Asset.Icons.arrowsSwitch.swiftUIImage
        return QuickSettingDropdownOption(
            text,
            icon: icon,
            active: active,
            requiresUpdate: requiresUpdate(portForwarding: true),
            selectCallback: { [weak self] dismissCallback in
                guard let self else { return }
                guard !requiresUpdate(portForwarding: true) else {
                    presentUpsellAlert()
                    dismissCallback()
                    return
                }
                portForwardingPropertyProvider.setPortForwarding(true)
                switch vpnManager.currentVpnProtocol {
                case .wireGuard:
                    log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnManager.set(portForwarding: true)
                    if vpnGateway.connection == .connected {
                        vpnManager.startNATPortMappingService()
                    }

                case .ike:
                    if vpnGateway.connection == .connected {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                        vpnGateway.retryConnection()
                    }

                // other protocols are not supported
                default:
                    assertionFailure("not supported protocol in port forwarding presenter")
                }

                dismissCallback()
            }
        )
    }

    private func requiresUpdate(portForwarding isOn: Bool) -> Bool {
        isOn
            ? currentUserTier.isFreeTier
            : false
    }

    private var currentUserTier: Int {
        (try? vpnGateway.userTier()) ?? .freeTier
    }
}
