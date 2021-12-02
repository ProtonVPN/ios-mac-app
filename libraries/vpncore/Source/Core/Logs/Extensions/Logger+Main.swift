//
//  Copyright (c) 2021 Proton AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import OSLog
import Logging

/// Main logger instance that should be used
public let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")

extension Logging.Logger {
    public static func instance(withCategory category: Logging.Logger.Category) -> Logging.Logger {
        var logger: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger.\(category.rawValue)")
        logger[metadataKey: Logging.Logger.MetaKey.category.rawValue] = .string(category.rawValue)
        return logger
    }
}
