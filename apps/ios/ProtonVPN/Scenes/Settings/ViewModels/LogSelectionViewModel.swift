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
    
    var pushHandler: ((LogsViewModel) -> Void)?
    
    init(logFileProvider: LogsFilesProvider) {
        let fileManager = FileManager()
        logCells = logFileProvider.logFiles.compactMap { (title, url) -> TableViewCellModel? in
            guard let url = url, fileManager.fileExists(atPath: url.path) else { return nil }
                        
            return TableViewCellModel.pushStandard(title: title, handler: {
                self.pushApplicationLogsViewController(withUrl: url, titled: title)
            })
        }
    }
    
    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            TableViewSection(title: "", showHeader: false, cells: logCells)
        ]
        return sections
    }
    
    private var logCells = [TableViewCellModel]()
        
    private func pushApplicationLogsViewController(withUrl url: URL, titled title: String) {
        pushHandler?(LogsViewModel(title: title, logFile: url))
    }
        
}
