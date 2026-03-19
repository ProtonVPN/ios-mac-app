//
//  Created on 05/02/2026 by adam.
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

import Foundation
import notify

extension IPCNotifications {
    public struct Token: ~Copyable {
        private(set) var rawValue: Int32 = NOTIFY_TOKEN_INVALID

        init(dispatchingOnMain name: String, handler: @MainActor @escaping (Int32) -> Void) {
            notify_register_dispatch(name, &rawValue, .main) { value in
                MainActor.assumeIsolated { handler(value) }
            }
        }

        init(dispatching name: String, on queue: DispatchQueue, handler: @escaping notify_handler_t) {
            notify_register_dispatch(name, &rawValue, queue, handler)
        }

        init(checking name: String) {
            notify_register_check(name, &rawValue)
        }

        deinit {
            notify_cancel(rawValue)
        }

        borrowing func setState(_ state: UInt64) {
            notify_set_state(rawValue, state)
        }

        consuming func cancel() {
            let raw = rawValue
            rawValue = NOTIFY_TOKEN_INVALID
            notify_cancel(raw)
        }
    }
}

extension IPCNotifications {
    public static func observeRawState(
        _ notification: Notification,
        handler: @MainActor @escaping (UInt64) -> Void
    ) -> Token {
        Token(dispatchingOnMain: notification.name) { token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            handler(state)
        }
    }

    public static func observeRawState(
        _ notification: Notification,
        queue: DispatchQueue,
        handler: @escaping (UInt64) -> Void
    ) -> Token {
        Token(dispatching: notification.name, on: queue) { token in
            var state: UInt64 = 0
            notify_get_state(token, &state)
            handler(state)
        }
    }

    public static func postRawState(_ notification: Notification, state: UInt64) {
        let token = Token(checking: notification.name)
        token.setState(state)
        notify_post(notification.name)
    }
}

extension IPCNotifications {
    public static func observeState<T: RawRepresentable>(
        _ notification: Notification,
        handler: @MainActor @escaping (T?) -> Void
    ) -> Token where T.RawValue == UInt64 {
        observeRawState(notification) { value in
            handler(T(rawValue: value))
        }
    }

    public static func observeState<T: RawRepresentable>(
        _ notification: Notification,
        queue: DispatchQueue,
        handler: @escaping (T?) -> Void
    ) -> Token where T.RawValue == UInt64 {
        observeRawState(notification, queue: queue) { value in
            handler(T(rawValue: value))
        }
    }

    public static func postState<T: RawRepresentable>(
        _ notification: Notification,
        state: T
    ) where T.RawValue == UInt64 {
        postRawState(notification, state: state.rawValue)
    }
}

extension IPCNotifications {
    private final class Box {
        var token: Token?
        init(_ token: consuming Token) {
            self.token = consume token
        }
    }

    public static func streamRawState(_ notification: Notification) -> AsyncStream<UInt64> {
        .init { continuation in
            let token = observeRawState(notification) { value in
                continuation.yield(value)
            }
            let box = Box(token)
            continuation.onTermination = { _ in
                box.token = nil
            }
        }
    }

    public static func streamState<T: RawRepresentable>(
        _ notification: Notification
    ) -> AsyncStream<T?> where T.RawValue == UInt64 {
        .init { continuation in
            let token = observeRawState(notification) { value in
                continuation.yield(T(rawValue: value))
            }
            let box = Box(token)
            continuation.onTermination = { _ in
                box.token = nil
            }
        }
    }
}
