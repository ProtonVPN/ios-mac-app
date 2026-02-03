//
//  ProtonVPNMenuController.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import Ergonomics
import LegacyCommon
import Strings

final class ProtonVPNMenuController: NSObject {
    lazy var aboutItem: NSMenuItem = .init(
        title: Localizable.menuAbout,
        action: #selector(aboutItemAction),
        keyEquivalent: ""
    ).with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var checkForUpdatesItem: NSMenuItem = .init(title: Localizable.menuCheckUpdates, action: #selector(checkForUpdatesAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var preferencesItem: NSMenuItem = .init(title: Localizable.menuPreferences, action: #selector(preferencesItemAction), keyEquivalent: ",").with {
        $0.isEnabled = false
        $0.target = self
    }

    var hideProtonItem: NSMenuItem = .init(title: Localizable.menuHideSelf, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h").with {
        $0.target = NSApp
    }

    var hideOthersItem: NSMenuItem = .init(title: Localizable.menuHideOthers, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").with {
        $0.keyEquivalentModifierMask = [.command, .option]
        $0.target = NSApp
    }

    lazy var showAllItem: NSMenuItem = .init(title: Localizable.menuShowAll, action: #selector(showAllItemAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var logOutItem: NSMenuItem = .init(title: Localizable.menuLogout, action: #selector(logOutItemAction), keyEquivalent: "w").with {
        $0.isEnabled = false
        $0.keyEquivalentModifierMask = [.command, .shift]
        $0.target = self
    }

    lazy var quitItem: NSMenuItem = .init(title: Localizable.menuQuit, action: #selector(quitItemAction), keyEquivalent: "q").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var menu = NSMenu(title: "ProtonVPN").with {
        $0.autoenablesItems = false
        $0.items = [
            aboutItem,
            checkForUpdatesItem,
            NSMenuItem.separator(),
            preferencesItem,
            NSMenuItem.separator(),
            hideProtonItem,
            hideOthersItem,
            showAllItem,
            NSMenuItem.separator(),
            logOutItem,
            quitItem,
        ]
    }

    private var viewModel: ProtonVpnMenuViewModel!

    func update(with viewModel: ProtonVpnMenuViewModel) {
        self.viewModel = viewModel
        viewModel.contentChanged = { [weak self] in self?.setupEphemeralView() }
    }

    // MARK: - Private functions

    private func setupEphemeralView() {
        preferencesItem.isEnabled = viewModel.isPreferencesEnabled
        logOutItem.isEnabled = viewModel.isLogOutEnabled
    }

    @objc
    private func aboutItemAction() {
        viewModel.openAboutAction()
    }

    @objc
    private func checkForUpdatesAction() {
        viewModel.checkForUpdatesAction()
    }

    @objc
    private func preferencesItemAction() {
        viewModel.openPreferencesAction()
    }

    @objc
    private func logOutItemAction() {
        viewModel.logOutAction()
    }

    @objc
    private func showAllItemAction() {
        viewModel.showAllAction()
    }

    @objc
    private func quitItemAction() {
        viewModel.quitAction()
    }
}
