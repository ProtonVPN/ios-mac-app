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

import XCTestDynamicOverlay

/// Automatically handles transferring a payload using `NotificationCenter`.
///
/// Using the `object` argument of the default `NotificationCenter` API is a common pitfall among Swift developers,
/// partly due to the added complexity of the intended payload delivery mechanism being a dictionary. Using `object` in
/// this way also prevents the ability to selectively listen to notifications sent from specific objects.
///
/// `TypedNotification` attempts to provide a more ergonomic interface, with some added safety checks in place to catch
/// programmer errors.
///
/// ```
/// struct StatsChanged: TypedNotification {
///     static let name = Notification.Name("ch.protonvpn.feature.statschanged")
///     let data: Stats
/// }
///
/// struct Stats {
///     let bytesSent: Int64
///     let bytesReceived: Int64
/// }
/// ```
///
/// Check `TypedNotificationTests` and the related `NotificationCenter.addObserver` extensions for more example usage.
public protocol TypedNotification<T> {
    associatedtype T
    static var name: Notification.Name { get }
    var data: T { get }
}

extension TypedNotification {
    static var dataKey: String { "ch.protonvpn.notificationcenter.notificationdata" }
}

protocol EmptyTypedNotification: TypedNotification<Void> { }
extension EmptyTypedNotification {
    var data: Void { return }
}

/// Wraps the observer token received from NotificationCenter and unregisters it when deallocated
public final class NotificationToken {
    private let notificationCenter: NotificationCenter
    private let observer: NSObjectProtocol
    private let name: NSNotification.Name?
    private let object: Any?

    init(notificationCenter: NotificationCenter, observer: NSObjectProtocol, name: Notification.Name?, object: Any?) {
        self.notificationCenter = notificationCenter
        self.observer = observer
        self.name = name
        self.object = object
    }

    deinit {
        notificationCenter.removeObserver(observer, name: name, object: object)
    }
}

extension NotificationCenter {

    public func post<T>(_ notification: some TypedNotification<T>, object: Any?) {
        let userInfo = [type(of: notification).dataKey: notification.data]
        post(name: type(of: notification).name, object: object, userInfo: userInfo)
    }

    /// Register a block to be executed when a notification with the given name is posted by the specified object, or
    /// any object if nil is provided.
    ///
    /// The notification center copies the handler, and strongly holds it until NotificationToken is deinited.
    public func addObserver(
        for notificationName: Notification.Name,
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (Notification) -> Void
    ) -> NotificationToken {
        let observer = addObserver(forName: notificationName, object: object, queue: queue, using: handler)
        return NotificationToken(notificationCenter: self, observer: observer, name: notificationName, object: object)
    }

    /// Register a block to be executed when the specified object, (or any object if nil is provided) posts a
    /// notification matching any of the names given.
    ///
    /// The notification center copies the block for each notification and strongly holds each separately while the
    /// corresponding token exists.
    public func addObservers(
        for notifications: [Notification.Name],
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (Notification) -> Void
    ) -> [NotificationToken] {
        return notifications.map { addObserver(for: $0, queue: queue, object: object, handler: handler) }
    }

    /// Similarly to the above overloads, returns a `NotificationToken` which is used to control the lifetime of the
    /// observer that handles responding to the subscribed notification.
    ///
    /// To avoid creating a retain cycle, make sure the handler does not hold a strong reference to the object which
    /// holds a strong reference to the returned `NotificationToken`.
    ///
    /// ```
    /// class StatisticsManager {
    ///
    ///     var token: NotificationToken?
    ///
    ///     func startObserving() {
    ///         let nc = NotificationCenter.default
    ///         // Creates retain cycle. `token` has to be manually set to nil, otherwise `StatisticsManager` will be
    ///         // forever held in memory
    ///         token = nc.addObserver(for: StatsChanged.self, object: self, handler: handleStatsChanged)
    ///
    ///         // `token` is automatically released whenever `StatisticsManager` goes out of scope.
    ///         token = nc.addObserver(for: StatsChanged.self, object: self) { [weak self] stats in
    ///             self?.handleSessionChanged(stats: stats)
    ///         }
    ///     }
    ///
    ///     func handleStatsChanged(stats: Stats) { ... }
    /// }
    /// ```
    ///
    /// The first argument of this function should conventionally be `forNotificationsOfType`, but one of the strengths
    /// of this extension is the ergonomics/conciseness of the API, when compared to the verbosity of the default
    /// NotificationCenter APIs
    public func addObserver<Notification, T>(
        for _: Notification.Type,
        queue: OperationQueue? = nil,
        object: Any?,
        handler: @escaping (T) -> Void
    ) -> NotificationToken where Notification: TypedNotification<T> {
        return addObserver(for: Notification.name, queue: queue, object: object) { notification in
            guard let data = notification.userInfo?[Notification.dataKey] else {
                XCTFail("Expected object of type \(T.self) stored under key: \(Notification.dataKey), got nil")
                return
            }
            guard let data = data as? T else {
                XCTFail("Expected object of type \(T.self) stored under key: \(Notification.dataKey), got \(String(describing: data))")
                return
            }

            handler(data)
        }
    }
}
