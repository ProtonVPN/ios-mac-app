//
//  LogFilesProvider.swift
//  Core
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

/// Provides all available log files together with their names
public protocol LogFilesProvider {
    var logFiles: [(String, URL?)] { get }
}

public protocol LogFilesProviderFactory {
    func makeLogFilesProvider() -> LogFilesProvider
    func makeLogFilesIncludingRotatedProvider() -> LogFilesProvider
}
