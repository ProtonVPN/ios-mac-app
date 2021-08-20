//
//  PMLog.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

// Version used only in WireGuard extension
public class PMLog {
    
    public enum LogLevel {
        case fatal, error, warn, info, debug, trace
        
        fileprivate var description: String {
            switch self {
            case .fatal:
                return "FATAL"
            case .error:
                return "ERROR"
            case .warn:
                return "WARN"
            case .info:
                return "INFO"
            case .debug:
                return "DEBUG"
            case .trace:
                return "TRACE"
            }
        }
    }
    
    public static func D(_ message: String, level: LogLevel = .info, filename: String = "ProtonVPN.log", file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        wg_log(.debug, message: message)
    }
    
    public static func ET(_ message: String, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        wg_log(.error, message: message)
    }
    
    public static func ET(_ error: Error, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        wg_log(.error, message: error.localizedDescription)
    }
    
    
}
