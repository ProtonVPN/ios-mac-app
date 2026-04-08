//
//  Created on 06/08/2025 by Max Kupetskyi.
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

import AppKit
import Combine
import Domain
import NetShield
import SwiftUI
import Theme

@MainActor
@Observable
final class QuickSettingsManager: CountriesSettingsDelegate {
    private(set) var configurations: [QuickSettingType: QuickSettingConfiguration] = [:]
    var activeType: QuickSettingType?
    private(set) var states: [QuickSettingType: QuickSettingState] = [:]
    private(set) var secureCoreEnabled = false
    private(set) var netShieldType: NetShieldType = .off
    private(set) var killSwitchEnabled = false
    private(set) var portForwardingEnabled = false
    private(set) var netShieldVisible = false
    private(set) var portForwardingVisible = VPNFeatureFlagType.portForwarding.enabled

    /// Bumped to notify the Observation framework of changes that don't
    /// directly mutate a tracked property (e.g. presenter-level updates).
    private(set) var revision: UInt = 0

    var onDidShowSetting: ((QuickSettingType) -> Void)?
    var onDidHideAllSettings: (() -> Void)?

    func setup(with viewModel: CountriesSectionViewModel) {
        let secureCore = viewModel.secureCorePresenter
        let netShield = viewModel.netShieldPresenter
        let killSwitch = viewModel.killSwitchPresenter
        let portForwarding = viewModel.portForwardingPresenter

        configurations = [
            .secureCoreDisplay: QuickSettingFactory.createConfiguration(type: .secureCoreDisplay, presenter: secureCore),
            .netShieldDisplay: QuickSettingFactory.createConfiguration(type: .netShieldDisplay, presenter: netShield),
            .killSwitchDisplay: QuickSettingFactory.createConfiguration(type: .killSwitchDisplay, presenter: killSwitch),
            .portForwardingDisplay: QuickSettingFactory.createConfiguration(type: .portForwardingDisplay, presenter: portForwarding),
        ]

        for (type, configuration) in configurations {
            states[type] = configuration.handleStateUpdate(connectionInfo: .connected(
                portForwardingEnabled: viewModel.portForwardingIsOn,
                supportsP2P: viewModel.connectedServerSupportsP2P,
                isConnected: viewModel.isConnected
            ))
            configuration.presenter.dismiss = { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.hideAllSettings()
                }
            }
            configuration.presenter.onChange = { [weak self] in
                self?.revision &+= 1
            }
        }

        netShieldVisible = viewModel.isNetShieldEnabled
        portForwardingVisible = VPNFeatureFlagType.portForwarding.enabled
        viewModel.delegate = self
        viewModel.updateSettings()
    }

    func handleButtonTap(for type: QuickSettingType) {
        if activeType == type {
            hideAllSettings()
        } else {
            activeType = type
            onDidShowSetting?(type)
        }
    }

    func hideAllSettings() {
        activeType = nil
        onDidHideAllSettings?()
    }

    var activeConfiguration: QuickSettingConfiguration? {
        guard let activeType else { return nil }
        return configurations[activeType]
    }

    func updateState(connectionInfo: ConnectionInfo) {
        for (type, config) in configurations {
            states[type] = config.handleStateUpdate(connectionInfo: connectionInfo)
        }
    }

    func reloadAllOptions() {
        revision &+= 1
    }

    func isVisible(_ type: QuickSettingType) -> Bool {
        switch type {
        case .secureCoreDisplay, .killSwitchDisplay:
            true
        case .netShieldDisplay:
            netShieldVisible
        case .portForwardingDisplay:
            portForwardingVisible
        }
    }

    func isEnabled(_ type: QuickSettingType) -> Bool {
        switch type {
        case .secureCoreDisplay:
            secureCoreEnabled
        case .netShieldDisplay:
            netShieldType != .off
        case .killSwitchDisplay:
            killSwitchEnabled
        case .portForwardingDisplay:
            portForwardingEnabled
        }
    }

    func buttonIcon(for type: QuickSettingType) -> Image {
        switch type {
        case .secureCoreDisplay:
            secureCoreEnabled ? Theme.Asset.Icons.locks.swiftUIImage : Theme.Asset.Icons.lock.swiftUIImage
        case .netShieldDisplay:
            switch netShieldType {
            case .off:
                Theme.Asset.Icons.shield.swiftUIImage
            case .level1:
                Theme.Asset.Icons.shieldHalfFilled.swiftUIImage
            case .level2:
                Theme.Asset.Icons.shieldFilled.swiftUIImage
            @unknown default:
                Theme.Asset.Icons.shield.swiftUIImage
            }
        case .killSwitchDisplay:
            killSwitchEnabled ? Theme.Asset.Icons.switchOn.swiftUIImage : Theme.Asset.Icons.switchOff.swiftUIImage
        case .portForwardingDisplay:
            portForwardingEnabled ? Theme.Asset.Icons.arrowsSwitch.swiftUIImage : Theme.Asset.Icons.arrowUpBounceLeft.swiftUIImage
        }
    }

    func buttonTooltip(for type: QuickSettingType) -> String {
        configurations[type]?.presenter.title ?? ""
    }

    // MARK: - CountriesSettingsDelegate

    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool, portForwarding: Bool) {
        secureCoreEnabled = secureCore
        netShieldType = netshield
        killSwitchEnabled = killSwitch
        portForwardingEnabled = portForwarding
    }
}
