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
import Foundation
import UserNotifications

import Dependencies

import CommonNetworking
import Domain
import LegacyCommon
import Strings
import VPNShared

final class NotificationManager: NSObject, NotificationManagerProtocol {
    private let delayBeforeDismissing: Duration = .seconds(5)
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
        UNUserNotificationCenter.current().delegate = self
        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(appStateChanged))
        setupActions()
    }

    lazy var portForwardingCategory: UNNotificationCategory = {
        let copyPortAction = UNNotificationAction(
            identifier: NotificationConstants.PortForwarding.copyPortActionIdentifier,
            title: Localizable.portForwardingInfoCopyButton,
            options: []
        )

        return .init(
            identifier: NotificationConstants.PortForwarding.portForwardingCategory,
            actions: [copyPortAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .customDismissAction
        )
    }()

    // MARK: - Private

    private func setupActions() {
        UNUserNotificationCenter.current().setNotificationCategories([portForwardingCategory])
    }

    @objc
    private func appStateChanged(_ notification: Notification) {
        if let newState = notification.object as? AppState {
            if case AppState.connected = newState, let server = appStateManager.activeConnection()?.server, shouldShowNotification {
                postTransient(connectedNotification(for: server))
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

    private func connectedNotification(for server: ServerModel) -> UNNotificationRequest {
        @Dependency(\.uuid) var uuidgen

        let content = UNMutableNotificationContent()
        content.title = Localizable.protonVpnConnected
        content.subtitle = connectSubtitle(forServer: server)
        content.body = connectInformativeText(forServer: server)
        let identifier = "connected-\(uuidgen)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
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

    private func post(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func postTransient(_ request: UNNotificationRequest) {
        post(request)

        Task { @MainActor in
            @Dependency(\.continuousClock) var clock

            try await clock.sleep(for: delayBeforeDismissing)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
        }
    }
}

// MARK: - Public

extension NotificationManager {
    func displayServerGoingOnMaintenance() {
        @Dependency(\.uuid) var uuidgen

        let content = UNMutableNotificationContent()
        content.title = Localizable.maintenanceOnServerDetectedTitle
        content.subtitle = Localizable.maintenanceOnServerDetectedSubtitle
        content.body = Localizable.maintenanceOnServerDetectedSubtitle
        let request = UNNotificationRequest(identifier: "maintenance-\(uuidgen)", content: content, trigger: nil)
        postTransient(request)
    }

    func displayPFChange(portNumber: UInt16) {
        let portString = String(portNumber)
        let content = UNMutableNotificationContent()
        content.title = "Proton VPN"
        content.subtitle = Localizable.portForwardingInfoSubtitle(portString)
        content.body = Localizable.portForwardingInfoBody
        content.userInfo = [NotificationConstants.PortForwarding.portNumberUserInfoKey: portString]
        content.categoryIdentifier = NotificationConstants.PortForwarding.portForwardingCategory
        let request = UNNotificationRequest(identifier: "port-\(portString)", content: content, trigger: nil)
        post(request)
    }

    func displayPFError() {
        let content = UNMutableNotificationContent()
        content.title = "Proton VPN"
        content.subtitle = Localizable.portForwardingErrorSubtitle
        content.body = Localizable.portForwardingErrorBody
        let request = UNNotificationRequest(identifier: Localizable.portForwardingErrorBody, content: content, trigger: nil)
        post(request)
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
