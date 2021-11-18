//
//  PMLog.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Logging

let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.WG.logger")

public struct WGLogHandler: LogHandler {
    
    public let formatter: PMLogFormatter
    public var logLevel: Logging.Logger.Level = .trace
    public var metadata = Logging.Logger.Metadata()
    
    public init(formatter: PMLogFormatter) {
        self.formatter = formatter
    }
    
    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }
    
    public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) { // swiftlint:disable:this function_parameter_count
        let text = formatter.formatMessage(level, message: message.description, function: function, file: file, line: line, metadata: convert(metadata: metadata), date: Date())
        print(text) // swiftlint:disable:this no_print
    }
    
    private func convert(metadata: Logging.Logger.Metadata?) -> [String: String] {
        let fullMetadata = (metadata != nil) ? self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }) : self.metadata
        return fullMetadata.reduce(into: [String: String](), { result, element in
            result[element.key] = element.value.description
        })
    }
}
