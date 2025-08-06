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
import LegacyCommon

// MARK: - Delegate Protocol

protocol QuickSettingsManagerDelegate: AnyObject {
    func quickSettingsManager(_ manager: QuickSettingsManager, didShowSetting type: QuickSettingType)
    func quickSettingsManagerDidHideAllSettings(_ manager: QuickSettingsManager)
    func quickSettingsManager(_ manager: QuickSettingsManager, needsWindowResize: Bool)
}

// MARK: - Manager Class

final class QuickSettingsManager {
    private var configurations: [QuickSettingConfiguration] = []
    private var viewControllers: [QuickSettingType: QuickSettingDetailViewController] = [:]
    private var currentlyShownType: QuickSettingType?

    weak var delegate: QuickSettingsManagerDelegate?

    // MARK: - Setup

    func setup(with viewModel: CountriesSectionViewModel, in parentViewController: CountriesSectionViewController) {
        configurations = [
            QuickSettingFactory.createConfiguration(
                type: .secureCoreDisplay,
                presenter: viewModel.secureCorePresenter,
                button: parentViewController.secureCoreBtn,
                container: parentViewController.secureCoreContainer
            ),
            QuickSettingFactory.createConfiguration(
                type: .netShieldDisplay,
                presenter: viewModel.netShieldPresenter,
                button: parentViewController.netShieldBtn,
                container: parentViewController.netshieldContainer
            ),
            QuickSettingFactory.createConfiguration(
                type: .killSwitchDisplay,
                presenter: viewModel.killSwitchPresenter,
                button: parentViewController.killSwitchBtn,
                container: parentViewController.killSwitchContainer
            ),
            QuickSettingFactory.createConfiguration(
                type: .portForwardingDisplay,
                presenter: viewModel.portForwardingPresenter,
                button: parentViewController.portForwardingBtn,
                container: parentViewController.portForwardingContainer
            ),
        ]

        for config in configurations {
            setupConfiguration(config, in: parentViewController)
        }
    }

    private func setupConfiguration(_ config: QuickSettingConfiguration, in parent: NSViewController) {
        let viewController = config.createViewController()
        viewControllers[config.type] = viewController

        // Setup view hierarchy
        viewController.viewWillAppear()
        config.container.addSubview(viewController.view)
        setupConstraints(for: viewController.view, in: config.container)

        // Setup interactions
        config.button.toolTip = config.presenter.title
        config.button.callback = { [weak self] _ in
            self?.handleButtonTap(for: config.type)
        }
        config.button.detailOpened = false

        config.presenter.dismiss = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.hideAllSettings()
            }
        }

        parent.addChild(viewController)
    }

    private func setupConstraints(for view: NSView, in container: NSBox) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalTo: view.heightAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }

    // MARK: - User Interaction

    func handleButtonTap(for type: QuickSettingType) {
        let container = getContainer(for: type)
        let isCurrentlyHidden = container?.isHidden ?? true

        hideAllSettings()

        if isCurrentlyHidden {
            showSetting(type)
        }
    }

    private func showSetting(_ type: QuickSettingType) {
        currentlyShownType = type

        guard let container = getContainer(for: type),
              let button = getButton(for: type) else { return }

        button.detailOpened = true
        container.isHidden = false

        delegate?.quickSettingsManager(self, didShowSetting: type)

        // Handle NetShield window resize requirement
        if type == .netShieldDisplay {
            delegate?.quickSettingsManager(self, needsWindowResize: true)
        }
    }

    func hideAllSettings() {
        currentlyShownType = nil

        for config in configurations {
            config.button.detailOpened = false
            config.container.isHidden = true
        }

        delegate?.quickSettingsManagerDidHideAllSettings(self)
    }

    // MARK: - State Updates

    func updateState(connectionInfo: ConnectionInfo?) {
        for config in configurations {
            let state = config.handleStateUpdate(connectionInfo: connectionInfo)
            updateViewController(for: config.type, with: state)
        }
    }

    private func updateViewController(for type: QuickSettingType, with state: QuickSettingState) {
        guard let viewController = viewControllers[type] else { return }

        switch (type, state) {
        case let (.portForwardingDisplay, .portForwarding(pfState)):
            (viewController as? QuickSettingDetailPFViewController)?
                .updatePortForwardingContainer(with: pfState)
        case (.netShieldDisplay, .netShield):
            viewController.updateNetshieldStats()
        default:
            break
        }
    }

    func reloadAllOptions() {
        viewControllers.values.forEach { $0.reloadOptions() }
    }

    // MARK: - Helper Methods

    private func getContainer(for type: QuickSettingType) -> NSBox? {
        configurations.first(where: { $0.type == type })?.container
    }

    private func getButton(for type: QuickSettingType) -> QuickSettingButton? {
        configurations.first(where: { $0.type == type })?.button
    }

    var isAnySettingDisplayed: Bool {
        currentlyShownType != nil
    }

    func getViewController<T: QuickSettingDetailViewController>(ofType _: T.Type) -> T? {
        viewControllers.values.compactMap { $0 as? T }.first
    }
}
