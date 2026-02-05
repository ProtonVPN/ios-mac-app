//
//  HelpMenuController.swift
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
import Dependencies
import Domain
import LegacyCommon
import Strings
import VPNAppCore

final class HelpMenuController: NSObject {
    lazy var reportAnIssueItem: NSMenuItem = .init(title: Localizable.reportAnIssue, action: #selector(reportAnIssueItemAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var logsItem: NSMenuItem = .init(title: Localizable.viewLogs, action: #selector(logsAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var logsWGItem: NSMenuItem = .init(title: Localizable.wireguardLogs, action: #selector(openWGLogsAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var logsPlutoniumItem: NSMenuItem = .init(title: Localizable.plutoniumLogs, action: #selector(openPlutoniumLogsAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var clearApplicationDataItem: NSMenuItem = .init(title: Localizable.clearApplicationData, action: #selector(clearApplicationDataItemAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    #if DEBUG
        lazy var showDebugScreenDataItem: NSMenuItem = .init(title: "Show debug screen", action: #selector(showDebugScreen), keyEquivalent: "z").with {
            $0.isEnabled = true
            $0.target = self
            $0.keyEquivalentModifierMask = [.command, .control]
        }
    #endif
    lazy var systemExtensionTutorialItem: NSMenuItem = .init(title: Localizable.systemExtensionTutorialMenuItem, action: #selector(systemExtensionTutorialAction), keyEquivalent: "").with {
        $0.target = self
    }

    lazy var helpItem: NSMenuItem = .init(title: "Proton VPN " + Localizable.help, action: #selector(helpItemAction), keyEquivalent: "").with {
        $0.isEnabled = true
        $0.target = self
    }

    lazy var helpMenu: NSMenu = .init(title: Localizable.help).with {
        $0.items = [
            reportAnIssueItem,
            logsItem,
            logsWGItem,
            logsPlutoniumItem,
            clearApplicationDataItem,
            systemExtensionTutorialItem,
            helpItem,
        ]
        #if DEBUG
            $0.items += [showDebugScreenDataItem]
        #endif
    }

    private var viewModel: HelpMenuViewModel!

    func update(with viewModel: HelpMenuViewModel) {
        self.viewModel = viewModel
        logsPlutoniumItem.isHidden = !VPNFeatureFlagType.plutoniumMacOS.enabled
    }

    // MARK: - Private

    @objc
    private func reportAnIssueItemAction() {
        viewModel.openReportBug()
    }

    @objc
    private func logsAction() {
        viewModel.openLogsFolderAction()
    }

    @objc
    private func openWGLogsAction() {
        viewModel.openWGVpnLogsFolderAction()
    }

    @objc
    private func openPlutoniumLogsAction() {
        viewModel.openPlutoniumLogsFolderAction()
    }

    @objc
    private func systemExtensionTutorialAction() {
        viewModel.systemExtensionTutorialAction()
    }

    @objc
    private func helpItemAction() {
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(.support)
    }

    @objc
    private func clearApplicationDataItemAction() {
        viewModel.selectClearApplicationData()
    }

    #if DEBUG
        @objc
        private func showDebugScreen() {
            viewModel.presentDebugScreen()
        }
    #endif
}
