//
//  NotificationManager.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import AppKit
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Strings
import UserNotifications
import VPNShared

class NotificationManager: NSObject, NotificationManagerProtocol {
    private let delayBeforeDismissing: TimeInterval = 5
    private let appStateManager: AppStateManager
    private let appSessionManager: AppSessionManager

    private var nonTransientState: AppState = .disconnected

    private var shouldShowNotification: Bool {
        @Dependency(\.defaultsProvider) var provider

        return appSessionManager.sessionStatus == .established
            && provider.getDefaults().bool(forKey: AppConstants.UserDefaults.systemNotifications)
    }

    init(appStateManager: AppStateManager, appSessionManager: AppSessionManager) {
        self.appStateManager = appStateManager
        self.appSessionManager = appSessionManager

        super.init()

        setNonTransientState(state: appStateManager.state)
        NSUserNotificationCenter.default.delegate = self
        UNUserNotificationCenter.current().delegate = self
        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(appStateChanged))
        setupActions()
    }

    // MARK: - Private

    private func setupActions() {
        // Define the custom actions.
        let copyPortAction = UNNotificationAction(
            identifier: NotificationConstants.PortForwarding.copyPortActionIdentifier,
            title: Localizable.portForwardingInfoCopyButton,
            options: []
        )
        // Define the notification type
        let portForwardingCategory =
            UNNotificationCategory(
                identifier: NotificationConstants.PortForwarding.portForwardingCategory,
                actions: [copyPortAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: "",
                options: .customDismissAction
            )
        // Register the notification type.
        UNUserNotificationCenter.current().setNotificationCategories([portForwardingCategory])
    }

    @objc
    private func appStateChanged(_ notification: Notification) {
        if let newState = notification.object as? AppState {
            if case AppState.connected = newState, let server = appStateManager.activeConnection()?.server, shouldShowNotification {
                fire(connectedNotification(for: server))
            }

            setNonTransientState(state: newState)
        }
    }

    private func setNonTransientState(state: AppState) {
        switch state {
        case .connected, .disconnected, .aborted, .error:
            nonTransientState = state
        default:
            break
        }
    }

    private func connectedNotification(for server: ServerModel) -> NSUserNotification {
        let notification = NSUserNotification()
        notification.title = "Proton VPN " + Localizable.connected
        notification.subtitle = connectSubtitle(forServer: server)
        notification.informativeText = connectInformativeText(forServer: server)
        notification.hasActionButton = false
        return notification
    }

    private func connectSubtitle(forServer server: ServerModel) -> String {
        if server.isSecureCore {
            server.entryCountry + " > " + server.exitCountry + " > " + server.name
        } else {
            server.country + " > " + server.name
        }
    }

    private func connectInformativeText(forServer _: ServerModel) -> String {
        Localizable.ipValue(appStateManager.activeConnection()?.serverIp.exitIp ?? Localizable.unavailable)
    }

    private func fire(_ notification: NSUserNotification) {
        NSUserNotificationCenter.default.deliver(notification)
        NSUserNotificationCenter.default.perform(
            #selector(NSUserNotificationCenter.removeDeliveredNotification(_:)),
            with: notification,
            afterDelay: delayBeforeDismissing
        )
    }
}

extension NotificationManager: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool {
        true
    }
}

// MARK: - Public

extension NotificationManager {
    func displayServerGoingOnMaintenance() {
        let notification = NSUserNotification()
        notification.title = Localizable.maintenanceOnServerDetectedTitle
        notification.subtitle = Localizable.maintenanceOnServerDetectedSubtitle
        notification.informativeText = Localizable.maintenanceOnServerDetectedSubtitle
        notification.hasActionButton = false
        fire(notification)
    }

    func displayPFChange(portNumber: UInt16) {
        let portString = String(portNumber)
        let content = UNMutableNotificationContent()
        content.title = "ProtonVPN"
        content.subtitle = Localizable.portForwardingInfoSubtitle(portString)
        content.body = Localizable.portForwardingInfoBody
        content.userInfo = [NotificationConstants.PortForwarding.portNumberUserInfoKey: portString]
        content.categoryIdentifier = NotificationConstants.PortForwarding.portForwardingCategory
        let request = UNNotificationRequest(identifier: portString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func displayPFError() {
        let content = UNMutableNotificationContent()
        content.title = "ProtonVPN"
        content.subtitle = Localizable.portForwardingErrorSubtitle
        content.body = Localizable.portForwardingErrorBody
        let request = UNNotificationRequest(identifier: Localizable.portForwardingErrorBody, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case NotificationConstants.PortForwarding.copyPortActionIdentifier:
            guard let portNumber = userInfo[NotificationConstants.PortForwarding.portNumberUserInfoKey] as? String else {
                break
            }
            Self.copyPortNumber(portNumber)
        default:
            break
        }

        completionHandler()
    }

    private static func copyPortNumber(_ portString: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(portString, forType: .string)
    }
}

private enum NotificationConstants {
    enum PortForwarding {
        static let portForwardingCategory: String = "PORT_FORWARDING"
        static let portNumberUserInfoKey: String = "PORT_NUMBER"
        static let copyPortActionIdentifier: String = "COPY_PORT_ACTION"
    }
}
