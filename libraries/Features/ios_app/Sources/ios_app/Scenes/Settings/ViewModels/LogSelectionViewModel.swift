//
//  LogSelectionViewModel.swift
//  ProtonVPN - Created on 10.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import LegacyCommon
import PMLogger

final class LogSelectionViewModel {
    var pushHandler: ((LogSource) -> Void)?
    var downloadAppleTVLogsHandler: (() -> Void)?

    init() {
        var cells = LogSource.visibleAppSources.compactMap { source in
            TableViewCellModel.pushStandard(title: source.title, handler: {
                self.pushApplicationLogsViewController(source: source)
            })
        }
        cells.append(
            .pushStandard(
                title: "Download ProtonVPN ATV logs",
                handler: { [weak self] in
                    self?.downloadAppleTVLogsHandler?()
                }
            )
        )
        self.logCells = cells
    }

    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            TableViewSection(title: "", showHeader: false, cells: logCells),
        ]
        return sections
    }

    private var logCells = [TableViewCellModel]()

    private func pushApplicationLogsViewController(source: LogSource) {
        pushHandler?(source)
    }
}
