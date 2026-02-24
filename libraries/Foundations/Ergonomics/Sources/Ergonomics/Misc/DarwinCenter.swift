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

public enum IPCNotifications {
    public typealias Callback = @MainActor () -> Void

    private static let center = CFNotificationCenterGetDarwinNotifyCenter()!
    private static let lock = NSLock()
    private static var callbacks: [CFString: Callback] = [:]

    public static func post(_ notification: Notification) {
        center.post(notification.name)
    }

    public static func observe(_ notification: Notification, callback: @escaping Callback) {
        let notificationName = notification.name as CFString
        lock.withLock {
            callbacks[notificationName] = callback
        }
        center.addObserver(notificationName)
    }

    fileprivate static let sharedCallback: CFNotificationCallback = { _, _, name, _, _ in
        name.map { name in MainActor.assumeIsolated { callbacks[name.rawValue]?() } }
    }
}

public extension IPCNotifications {
    struct Notification {
        public let name: String

        public init(name: String) {
            self.name = name
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
}
