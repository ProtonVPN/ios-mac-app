//
//  LogsViewModel.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import LegacyCommon
import PMLogger

struct LogsViewModel {

    let title: String
    let logContent: LogContent

    func loadLogs(callback: @escaping (String) -> Void) {
        logContent.loadContent(callback: callback)
    }
    
}
