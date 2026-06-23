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
import Sharing

/// A simple wrapper type for creating a ``SharedReaderKey`` from a value getter and an ``AsyncStream`` of updates.
public struct StreamReaderKey<Value: Sendable>: SharedReaderKey {
    public let id: String
    private let _load: @Sendable () -> Value
    private let _subscribe: @Sendable (SharedSubscriber<Value>) -> SharedSubscription

    public init(
        id: String,
        read: @escaping @Sendable () -> Value,
        updates: @escaping @Sendable () -> AsyncStream<Value>
    ) {
        self.id = id
        self._load = read
        self._subscribe = { subscriber in
            let task = Task {
                for await value in updates() {
                    subscriber.yield(value)
                }
            }
            return SharedSubscription { task.cancel() }
        }
    }

    /// Kind of jank but lets us skip an extra `transform` step
    public init<Source: Sendable>(
        id: String,
        read: @escaping @Sendable () -> Source,
        updates: @escaping @Sendable () -> AsyncStream<Source>,
        transform: @escaping @Sendable (Source) -> Value
    ) {
        self.id = id
        self._load = { transform(read()) }
        self._subscribe = { subscriber in
            let task = Task {
                for await value in updates() {
                    subscriber.yield(transform(value))
                }
            }
            return SharedSubscription { task.cancel() }
        }
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        continuation.resume(returning: _load())
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        _subscribe(subscriber)
    }
}

public extension Effect {
    /// Streams an `AsyncStream`'s values into the reducer as actions. Used instead of ``SharedReader`` for error
    /// values, or other situations where modeling messages as actions that produce effects makes more sense.
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
