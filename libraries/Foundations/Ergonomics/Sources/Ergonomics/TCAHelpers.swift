//
//  Created on 28/11/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Combine
import ComposableArchitecture
import Dispatch

public extension Effect {
    static func listen<StreamElement>(
        to stream: @escaping @autoclosure () -> AsyncStream<StreamElement>,
        priority: TaskPriority? = nil,
        reinjecting toAction: @escaping @MainActor @Sendable (StreamElement) async throws -> Action,
        catch handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
    ) -> Self {
        run(
            priority: priority,
            operation: { send in
                for await value in stream() {
                    try await send(toAction(value))
                }
            },
            catch: handler
        )
    }
}
