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
import vpncore

class HelpMenuController: NSObject {
    
    @IBOutlet weak var helpMenu: NSMenu!
    @IBOutlet weak var reportAnIssueItem: NSMenuItem!
    @IBOutlet weak var logsItem: NSMenuItem!
    @IBOutlet weak var logsOvpnItem: NSMenuItem!
    @IBOutlet weak var logsWGItem: NSMenuItem!
    @IBOutlet weak var helpItem: NSMenuItem!
    @IBOutlet weak var systemExtensionTutorialItem: NSMenuItem!
    @IBOutlet weak var clearApplicationDataItem: NSMenuItem!
    
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
        helpMenu.title = LocalizedString.help
        
        reportAnIssueItem.title = LocalizedString.reportAnIssue
        reportAnIssueItem.isEnabled = true
        reportAnIssueItem.target = self
        reportAnIssueItem.action = #selector(reportAnIssueItemAction)
        
        logsItem.title = LocalizedString.viewLogs
        logsItem.isEnabled = true
        logsItem.target = self
        logsItem.action = #selector(logsAction)
        
        logsOvpnItem.title = LocalizedString.openVpnLogs
        logsOvpnItem.isEnabled = true
        logsOvpnItem.target = self
        logsOvpnItem.action = #selector(openVpnLogsAction)
        
        logsWGItem.title = LocalizedString.wireguardLogs
        logsWGItem.isEnabled = true
        logsWGItem.target = self
        logsWGItem.action = #selector(openWGLogsAction)
        
        clearApplicationDataItem.title = LocalizedString.clearApplicationData
        clearApplicationDataItem.isEnabled = true
        clearApplicationDataItem.target = self
        clearApplicationDataItem.action = #selector(clearApplicationDataItemAction)

        systemExtensionTutorialItem.title = LocalizedString.systemExtensionTutorialMenuItem
        systemExtensionTutorialItem.target = self
        systemExtensionTutorialItem.action = #selector(systemExtensionTutorialAction)

        helpItem.title = "Proton VPN " + LocalizedString.help
        helpItem.isEnabled = true
        helpItem.target = self
        helpItem.action = #selector(helpItemAction)
    }

    @objc private func reportAnIssueItemAction() {
        viewModel.openReportBug()
    }

    @objc private func logsAction() {
        viewModel.openLogsFolderAction()
    }

    @objc private func openVpnLogsAction() {
        viewModel.openOpenVpnLogsFolderAction()
    }

    @objc private func openWGLogsAction() {
        viewModel.openWGVpnLogsFolderAction()
    }

    @objc private func systemExtensionTutorialAction() {
        viewModel.systemExtensionTutorialAction()
    }

    @objc private func helpItemAction() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.support)
    }

    @objc private func clearApplicationDataItemAction() {
        viewModel.selectClearApplicationData()
    }
}
