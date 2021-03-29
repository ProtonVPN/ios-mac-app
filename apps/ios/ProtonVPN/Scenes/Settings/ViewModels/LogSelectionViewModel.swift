//
//  LogSelectionViewModel.swift
//  ProtonVPN - Created on 10.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import vpncore

class LogSelectionViewModel {
    
    private let settingsService: SettingsService
    
    var contentChanged: (() -> Void)?
    var pushHandler: ((UIViewController) -> Void)?
    
    private var openVpnLogs: String? {
        didSet {
            openVpnLogsRecieved()
        }
    }
    
    private var openVpnLogFile: URL? {
        didSet {
            openVpnLogsRecieved()
        }
    }
    
    init(vpnManager: VpnManagerProtocol, settingsService: SettingsService) {
        self.settingsService = settingsService
        vpnManager.logsContent(for: .openVpn(.undefined)) { [weak self] (contents) in
            self?.openVpnLogs = contents
        }
        vpnManager.logFile(for: .openVpn(.undefined)) { [weak self] (file) in
            self?.openVpnLogFile = file
        }
    }
    
    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            logs
        ]
        
        return sections
    }
    
    private var logs: TableViewSection {
        var cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.applicationLogs, handler: { [pushApplicationLogsViewController] in
                pushApplicationLogsViewController()
            })
        ]
        
        if openVpnLogs != nil {
            cells.append(
                .pushStandard(title: LocalizedString.openVpnLogs, handler: { [pushOpenVpnLogsViewController] in
                    pushOpenVpnLogsViewController()
                })
            )
        }
        
        return TableViewSection(title: "", cells: cells)
    }
    
    private func openVpnLogsRecieved() {
        if openVpnLogs != nil && openVpnLogFile != nil {
            DispatchQueue.main.async { [weak self] in
                self?.contentChanged?()
            }
        }
    }
    
    private func pushApplicationLogsViewController() {
        guard let logFile = PMLog.logFile() else { return }
        
        let logsViewModel = LogsViewModel(title: LocalizedString.applicationLogs, logs: PMLog.logsContent(), logFile: logFile)
        pushHandler?(settingsService.makeLogsViewController(viewModel: logsViewModel))
    }
    
    private func pushOpenVpnLogsViewController() {
        guard let logString = openVpnLogs, let logFile = openVpnLogFile else { return }
        
        let logsViewModel = LogsViewModel(title: LocalizedString.openVpnLogs, logs: logString, logFile: logFile)
        pushHandler?(settingsService.makeLogsViewController(viewModel: logsViewModel))
    }
    
}
