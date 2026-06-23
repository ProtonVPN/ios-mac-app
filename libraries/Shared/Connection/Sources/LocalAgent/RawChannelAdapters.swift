//
//  Created on 22/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Foundation
import IPCErgonomics
import Sharing

/// Simple adapter to transform ``RawChannel``s into ``SharedReader``s.
public struct RawChannelKey<Value: Sendable>: SharedReaderKey {
    public let id: String
    private let read: @Sendable () -> Value
    private let updates: @Sendable () -> AsyncStream<Value>

    public init(
        id: String,
        read: @escaping @Sendable () -> Value,
        updates: @escaping @Sendable () -> AsyncStream<Value>
    ) {
        self.id = id
        self.read = read
        self.updates = updates
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        continuation.resume(returning: read())
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let task = Task {
            for await value in updates() {
                subscriber.yield(value)
            }
        }
        return SharedSubscription { task.cancel() }
    }
}

public extension Effect {
    static func observe<Payload>(
        _ stream: AsyncStream<Payload>,
        action: @escaping @Sendable (Payload) -> Action
    ) -> Self {
        .run { send in
            for await payload in stream {
                await send(action(payload))
            }
        }
    }
}
