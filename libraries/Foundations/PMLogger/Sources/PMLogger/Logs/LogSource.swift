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
    case wireguard
    #if os(iOS) && DEBUG
        case protun
        case protunArchive
    #endif
    #if os(macOS)
        case plutonium
    #endif

    case osLog

    // osLog source is used only for bug reports
    #if os(iOS) && DEBUG
        public static let visibleAppSources: [LogSource] = [.app, .wireguard, .protun]
    #else
        public static let visibleAppSources: [LogSource] = [.app, .wireguard]
    #endif

    public var title: String {
        switch self {
        case .app: Localizable.applicationLogs
        case .wireguard: Localizable.wireguardLogs
        #if os(iOS) && DEBUG
            case .protun: Localizable.protunLogs
            case .protunArchive: Localizable.protunLogs + " Archive (Experimental)"
        #endif
        #if os(macOS)
            case .plutonium: Localizable.plutoniumLogs
        #endif
        case .osLog: "os_log" // Not used in UI
        }
    }
}
