//
//  Created on 13/01/2025.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ComposableArchitecture
import Connection

public extension Reducer {
    func logActions(_ logger: ActionLogger<Action>) -> LogActionReducer<Self> {
        LogActionReducer<Self>(base: self, logger: logger)
    }
}

public struct ActionLogger<Action>: Sendable {
    private let _logAction: @Sendable (_ receivedAction: Action) -> Void

    public init(logAction: @escaping @Sendable (_ receivedAction: Action) -> Void) {
        _logAction = logAction
    }

    public func logAction(receivedAction: Action) {
        _logAction(receivedAction)
    }
}

public struct LogActionReducer<Base: Reducer>: Reducer {
    let base: Base
    let logger: ActionLogger<Base.Action>

    init(base: Base, logger: ActionLogger<Base.Action>) {
        self.base = base
        self.logger = logger
    }

    public func reduce(
        into state: inout Base.State, action: Base.Action
    ) -> Effect<Base.Action> {
        logger.logAction(receivedAction: action)
        return base.reduce(into: &state, action: action)
    }
}

extension ActionLogger {
    package static var connectionLogger: Self {
        Self {
            log.debug("\(ConnectionFeature.self) received action: \($0)", category: .connection)
        }
    }
}
