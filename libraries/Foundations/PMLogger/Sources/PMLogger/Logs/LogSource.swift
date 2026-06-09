//
//  LogSource.swift
//  Core
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Strings

public enum LogSource: CaseIterable {
    case app
    case protun
    #if DEBUG
        case protunArchive
    #endif
    #if os(iOS)
        case transactionLog
    #endif
    #if os(macOS)
        case plutonium
    #endif

    case osLog

    // osLog source is used only for bug reports
    #if os(iOS)
        public static let visibleAppSources: [LogSource] = [.app, .protun, .transactionLog]
    #elseif os(macOS)
        public static let visibleAppSources: [LogSource] = [.app, .protun]
    #else
        public static let visibleAppSources: [LogSource] = [.app]
    #endif

    public var title: String {
        switch self {
        case .app: Localizable.applicationLogs
        case .protun: Localizable.protunLogs
        #if DEBUG
            case .protunArchive: Localizable.protunLogs + " Archive (Experimental)"
        #endif
        #if os(iOS)
            case .transactionLog: Localizable.transactionLog
        #endif
        #if os(macOS)
            case .plutonium: Localizable.plutoniumLogs
        #endif
        case .osLog: "os_log" // Not used in UI
        }
    }
}
