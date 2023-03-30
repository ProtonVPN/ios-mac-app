//
//  Created on 08/03/2023.
//
//  Copyright (c) 2023 Proton AG
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
import NotificationCenter

public protocol StrongNotification<T> {
    associatedtype T
    static var name: Notification.Name { get }
    var data: T { get }
}

extension StrongNotification {
    static var dataKey: String { "ch.protonvpn.notificationcenter.notificationdata" }
}

/// Wraps the observer token received from NotificationCenter and unregisters it when deallocated
public final class NotificationToken {
    private let notificationCenter: NotificationCenter
    private let token: NSObjectProtocol

    init(notificationCenter: NotificationCenter, token: NSObjectProtocol) {
        self.notificationCenter = notificationCenter
        self.token = token
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}

extension NotificationCenter {

    public func post<T>(_ notification: some StrongNotification<T>, object: Any?) {
        let userInfo = [type(of: notification).dataKey: notification.data]
        post(name: type(of: notification).name, object: object, userInfo: userInfo)
    }

    public func addObserver(
        for notificationName: Notification.Name,
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (Notification) -> Void
    ) -> NotificationToken {
        let token = addObserver(forName: notificationName, object: object, queue: queue, using: handler)
        return NotificationToken(notificationCenter: self, token: token)
    }

    public func addObservers(
        for notifications: [Notification.Name],
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (Notification) -> Void
    ) -> [NotificationToken] {
        return notifications.map { addObserver(for: $0, queue: queue, object: object, handler: handler) }
    }

    public func addObserver<Notification, T>(
        for protonNotification: Notification.Type,
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (T) -> Void
    ) -> NotificationToken where Notification: StrongNotification<T> {
        let token = addObserver(forName: Notification.name, object: object, queue: queue) { notification in
            guard let data = notification.userInfo?[Notification.dataKey] as? T else {
                Environment._assertionFailure("Expected object of type \(T.self) stored under key: \(Notification.dataKey)", #file, #line)
                return
            }

            handler(data)
        }
        return NotificationToken(notificationCenter: self, token: token)
    }
}
