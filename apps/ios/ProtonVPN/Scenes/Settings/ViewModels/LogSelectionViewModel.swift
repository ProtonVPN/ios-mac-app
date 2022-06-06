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

final class LogSelectionViewModel {
    
    var pushHandler: ((LogSource) -> Void)?
    
    init() {
        logCells = LogSource.visibleAppSources.compactMap { source in
            return TableViewCellModel.pushStandard(title: source.title, handler: {
                self.pushApplicationLogsViewController(source: source)
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
        
    private func pushApplicationLogsViewController(source: LogSource) {
        pushHandler?(source)
    }
        
}
