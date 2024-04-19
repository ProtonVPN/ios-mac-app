//
//  LogFilesProvider.swift
//  Core
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Strings

public enum LogSource: CaseIterable {
    case app
    case wireguard
    case osLog

    // osLog source is used only for bug reports
    public static var visibleAppSources: [LogSource] = [.app, .wireguard]

    public var title: String {
        switch self {
        case .app: return Localizable.applicationLogs
        case .wireguard: return Localizable.wireguardLogs
        case .osLog: return "os_log" // Not used in UI
        }
    }
}
