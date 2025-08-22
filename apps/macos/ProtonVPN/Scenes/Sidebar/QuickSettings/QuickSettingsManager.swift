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
}

// MARK: - Manager Class

final class QuickSettingsManager {
    private var configurations: [QuickSettingConfiguration] = []
    private var viewControllers: [QuickSettingType: QuickSettingDetailViewController] = [:]
    private var currentlyShownType: QuickSettingType?
    private var containers: [QuickSettingType: NSBox] = [:]

    weak var parentViewController: NSViewController?
    weak var delegate: QuickSettingsManagerDelegate?

    // MARK: - Setup

    func setup(with viewModel: CountriesSectionViewModel, in parentViewController: CountriesSectionViewController) {
        configurations = [
            QuickSettingFactory.createConfiguration(
                type: .secureCoreDisplay,
                presenter: viewModel.secureCorePresenter,
                button: parentViewController.secureCoreBtn
            ),
            QuickSettingFactory.createConfiguration(
                type: .netShieldDisplay,
                presenter: viewModel.netShieldPresenter,
                button: parentViewController.netShieldBtn
            ),
            QuickSettingFactory.createConfiguration(
                type: .killSwitchDisplay,
                presenter: viewModel.killSwitchPresenter,
                button: parentViewController.killSwitchBtn
            ),
            QuickSettingFactory.createConfiguration(
                type: .portForwardingDisplay,
                presenter: viewModel.portForwardingPresenter,
                button: parentViewController.portForwardingBtn
            ),
        ]

        for config in configurations {
            setupConfiguration(config, in: parentViewController)
        }

        self.parentViewController = parentViewController
    }

    private func setupConfiguration(_ config: QuickSettingConfiguration, in parent: NSViewController) {
        let viewController = config.createViewController()
        viewControllers[config.type] = viewController

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
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - User Interaction

    func handleButtonTap(for type: QuickSettingType) {
        let isCurrentlyShown = currentlyShownType == type

        hideAllSettings()

        if !isCurrentlyShown {
            showSetting(type)
        }
    }

    private func showSetting(_ type: QuickSettingType) {
        currentlyShownType = type

        guard let button = getButton(for: type),
              let parentView = parentViewController?.view else { return }

        // Create container if it doesn't exist
        let container = createContainer(in: parentView)
        containers[type] = container

        // Get or create view controller
        guard let viewController = viewControllers[type] else { return }

        // Setup view hierarchy
        viewController.viewWillAppear()
        container.addSubview(viewController.view)
        setupConstraints(for: viewController.view, in: container)

        button.detailOpened = true

        delegate?.quickSettingsManager(self, didShowSetting: type)
    }

    private func createContainer(in parentView: NSView) -> NSBox {
        let container = NSBox().with {
            $0.boxType = .custom
            $0.borderType = .noBorder
            $0.cornerRadius = 4
            $0.titlePosition = .noTitle
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.fillColor = NSColor.clear
        }

        parentView.addSubview(container)

        // Setup constraints
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 48),
            container.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            container.widthAnchor.constraint(equalTo: parentView.widthAnchor),
            container.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])

        return container
    }

    func hideAllSettings() {
        currentlyShownType = nil

        for config in configurations {
            config.button.detailOpened = false
        }

        // Remove and destroy all containers
        for (type, container) in containers {
            container.removeFromSuperview()
            // Remove child view controller
            if let viewController = viewControllers[type] {
                viewController.removeFromParent()
            }
        }
        containers.removeAll()

        delegate?.quickSettingsManagerDidHideAllSettings(self)
    }

    // MARK: - State Updates

    func updateState(connectionInfo: ConnectionInfo) {
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

    private func getButton(for type: QuickSettingType) -> QuickSettingButton? {
        configurations.first(where: { $0.type == type })?.button
    }

    var isAnySettingDisplayed: Bool {
        currentlyShownType != nil
    }
}
