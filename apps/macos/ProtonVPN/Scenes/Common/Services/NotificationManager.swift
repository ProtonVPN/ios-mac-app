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
import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import LegacyCommon
import Strings
import UserNotifications
import VPNAppCore
import VPNShared

extension NotificationManager: @retroactive DependencyKey {
    public static let liveValue: NotificationManager = {
        let implementation = NotificationManagerImplementation()
        return NotificationManager(
            displayServerGoingOnMaintenance: { implementation.displayServerGoingOnMaintenance() },
            displayPFChange: { implementation.displayPFChange(portNumber: $0) },
            displayPFError: { implementation.displayPFError() }
        )
    }()
}

private final class NotificationManagerImplementation: NSObject {
    private let delayBeforeDismissing: Duration = .seconds(5)
    @SharedReader(.sessionStatus) private var sessionStatus: SessionStatus
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    private var cancellables = Set<AnyCancellable>()

    private var shouldShowNotification: Bool {
        @SharedReader(.systemNotifications) var systemNotifications

        return sessionStatus == .established && systemNotifications
    }

    override init() {
        super.init()

        UNUserNotificationCenter.current().delegate = self
        $connectionState
            .publisher
            .compactMap { state -> ConnectedPeer? in
                guard case let .connected(_, data) = state else { return nil }
                return ConnectedPeer(server: data.currentPeer, exitIP: state.vpnExitIP)
            }
            // Deduplicated on the peer alone: the exit address can arrive after the tunnel comes up,
            // and a second notification for the same connection would be worse than a stale address.
            .removeDuplicates { $0.server == $1.server }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peer in
                self?.vpnConnectionChanged(peer)
            }
            .store(in: &cancellables)
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

    private func vpnConnectionChanged(_ peer: ConnectedPeer) {
        if shouldShowNotification {
            postTransient(connectedNotification(for: peer))
        }
    }

    private func connectedNotification(for peer: ConnectedPeer) -> UNNotificationRequest {
        @Dependency(\.uuid) var uuidgen

        let content = UNMutableNotificationContent()
        content.title = Localizable.protonVpnConnected
        content.subtitle = connectSubtitle(forServer: peer.server)
        content.body = Localizable.ipValue(peer.exitIP ?? Localizable.unavailable)
        let identifier = "connected-\(uuidgen)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    private func connectSubtitle(forServer server: Server) -> String {
        if server.logical.feature.contains(.secureCore) {
            server.logical.entryCountry + " > " + server.logical.exitCountry + " > " + server.logical.name
        } else {
            server.logical.exitCountry + " > " + server.logical.name
        }
    }

    /// The server a notification is about, with the address traffic actually leaves from.
    ///
    /// The address comes from ``ConnectionState/vpnExitIP`` rather than from the server list, so that
    /// the notification, the window header and the menu bar all report what the connection details
    /// screen reports.
    private struct ConnectedPeer: Equatable {
        let server: Server
        let exitIP: String?
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

extension NotificationManagerImplementation {
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

extension NotificationManagerImplementation: UNUserNotificationCenterDelegate {
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
