//
//  PMLogFormatter.swift
//  Core
//
//  Created by Jaroslav on 2021-11-12.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Logging

public protocol PMLogFormatter {
    func formatMessage(_ level: Logging.Logger.Level, message: String, function: String, file: String, line: UInt, metadata: [String: String], date: Date) -> String // swiftlint:disable:this function_parameter_count
}
