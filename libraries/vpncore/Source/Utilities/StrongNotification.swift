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

extension NotificationCenter {

    static var dataKey = "ProtonNotificationData"

    public func post<T>(_ notification: some StrongNotification<T>, object: Any?) {
        post(name: type(of: notification).name, object: object, userInfo: [Self.dataKey: notification.data])
    }

    public func addObserver<Notification, T>(
        for protonNotification: Notification.Type,
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (T) -> Void
    ) where Notification: StrongNotification<T> {
        addObserver(forName: Notification.name, object: object, queue: queue) { notification in
            guard let data = notification.userInfo?[Self.dataKey] as? T else {
                log.error("Expected object of type \(T.self) stored under key: \(Self.dataKey)")
                return
            }

            handler(data)
        }
    }
}
