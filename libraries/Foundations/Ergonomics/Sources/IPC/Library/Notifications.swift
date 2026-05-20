//
//  Created on 05/02/2026.
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
import os.lock

public enum IPCNotifications {
    public typealias Callback = @MainActor () -> Void

    private static let center = CFNotificationCenterGetDarwinNotifyCenter()!
    private static let callbacks: OSAllocatedUnfairLock<[CFString: Callback]> = .init(initialState: [:])
}

public extension IPCNotifications {
    struct Notification: Sendable {
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }
}

public extension IPCNotifications {
    static func post(_ notification: Notification) {
        center.post(notification.name)
    }

    static func observe(_ notification: Notification, callback: @escaping Callback) {
        let notificationName = notification.name as CFString
        callbacks.withLock {
            $0[notificationName] = callback
        }
        center.addObserver(notificationName)
    }

    static func stopObserving(_ notification: Notification) {
        let notificationName = notification.name as CFString
        _ = callbacks.withLock {
            $0.removeValue(forKey: notificationName)
        }
        center.removeObserver(notificationName)
    }

    fileprivate static let sharedCallback: CFNotificationCallback = { _, _, name, _, _ in
        name.map { name in
            let callback = callbacks.withLock { $0[name.rawValue] }
            MainActor.assumeIsolated { callback?() }
        }
    }
}

private extension CFNotificationCenter {
    func post(_ name: String) {
        CFNotificationCenterPostNotification(
            self,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    func addObserver(_ name: CFString) {
        CFNotificationCenterAddObserver(
            self,
            nil,
            IPCNotifications.sharedCallback,
            name,
            nil,
            .deliverImmediately
        )
    }

    func removeObserver(_ name: CFString) {
        CFNotificationCenterRemoveObserver(
            self,
            nil,
            CFNotificationName(name),
            nil
        )
    }
}
