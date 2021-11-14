//
//  Level+Print.swift
//  Core
//
//  Created by Jaroslav on 2021-11-12.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Logging

extension Logging.Logger.Level {
    public var emoji: String {
        switch self {
        case .trace:
            return "⚪"
        case .debug:
            return "🟢"
        case .info:
            return "🔵"
        case .notice:
            return "🟠"
        case .warning:
            return "🟡"
        case .error:
            return "🔴"
        case .critical:
            return "💥"
        }
    }
}
