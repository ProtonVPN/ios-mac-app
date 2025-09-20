//
//  Created on 09/07/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Logging

/// A marker protocol to allow treating TCP and UDP flow handler actors under a common type.
/// Used to simplify API surfaces (e.g. registration) where dynamic casting is needed.
/// This is necessary since actors can't inherit from a shared base class.
protocol FlowHandler {
    var id: UUID { get }
}

extension FlowHandler {
    @inlinable
    public func logInfo(
        _ message: @autoclosure () -> Logger.Message,
        metadata _: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if DEBUG
            let message = "(\(id)) \(message())"
            log.info(.init(stringLiteral: message), file: file, function: function, line: line)
        #else
            log.info(message(), file: file, function: function, line: line)
        #endif
    }

    @inlinable
    public func logDebug(
        _ message: @autoclosure () -> Logger.Message,
        metadata _: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if DEBUG
            let message = "(\(id)) \(message())"
            log.debug(.init(stringLiteral: message), file: file, function: function, line: line)
        #else
            log.debug(message(), file: file, function: function, line: line)
        #endif
    }

    @inlinable
    public func logError(
        _ message: @autoclosure () -> Logger.Message,
        metadata _: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if DEBUG
            let message = "(\(id)) \(message())"
            log.error(.init(stringLiteral: message), file: file, function: function, line: line)
        #else
            log.error(message(), file: file, function: function, line: line)
        #endif
    }
}
