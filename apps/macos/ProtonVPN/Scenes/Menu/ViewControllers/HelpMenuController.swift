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
import LegacyCommon
import Strings
import VPNAppCore

class HelpMenuController: NSObject {
    @IBOutlet var helpMenu: NSMenu!
    @IBOutlet var reportAnIssueItem: NSMenuItem!
    @IBOutlet var logsItem: NSMenuItem!
    @IBOutlet var logsWGItem: NSMenuItem!
    @IBOutlet var helpItem: NSMenuItem!
    @IBOutlet var systemExtensionTutorialItem: NSMenuItem!
    @IBOutlet var clearApplicationDataItem: NSMenuItem!

    private var viewModel: HelpMenuViewModel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupPersistentView()
    }

    func update(with viewModel: HelpMenuViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Private

    private func setupPersistentView() {
        helpMenu.title = Localizable.help

        reportAnIssueItem.title = Localizable.reportAnIssue
        reportAnIssueItem.isEnabled = true
        reportAnIssueItem.target = self
        reportAnIssueItem.action = #selector(reportAnIssueItemAction)

        logsItem.title = Localizable.viewLogs
        logsItem.isEnabled = true
        logsItem.target = self
        logsItem.action = #selector(logsAction)

        logsWGItem.title = Localizable.wireguardLogs
        logsWGItem.isEnabled = true
        logsWGItem.target = self
        logsWGItem.action = #selector(openWGLogsAction)

        clearApplicationDataItem.title = Localizable.clearApplicationData
        clearApplicationDataItem.isEnabled = true
        clearApplicationDataItem.target = self
        clearApplicationDataItem.action = #selector(clearApplicationDataItemAction)

        systemExtensionTutorialItem.title = Localizable.systemExtensionTutorialMenuItem
        systemExtensionTutorialItem.target = self
        systemExtensionTutorialItem.action = #selector(systemExtensionTutorialAction)

        helpItem.title = "Proton VPN " + Localizable.help
        helpItem.isEnabled = true
        helpItem.target = self
        helpItem.action = #selector(helpItemAction)
    }

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
}
