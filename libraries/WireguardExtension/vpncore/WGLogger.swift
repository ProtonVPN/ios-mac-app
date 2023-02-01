//
//  PMLog.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Logging
import PMLogger

let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.WG.logger")

public final class WGLogHandler: ParentLogHandler {

    override public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let text = formatter.formatMessage(level, message: message.description, function: function, file: file, line: line, metadata: convert(metadata: metadata), date: Date())
        wg_log(.info, message: text)
    }
}
