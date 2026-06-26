//
//  IosAlertService.swift
//  ProtonVPN - Created on 09/09/2019.
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

import Announcement
import BugReport
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Modals
import Payments
import Strings
import SwiftUI
import Telemetry
import UIKit
import VPNAppCore

final class IosAlertService {
    typealias Factory =
        AppSessionManagerFactory &
        NavigationServiceFactory &
        UIAlertServiceFactory

    private let factory: Factory

    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()

    private let paymentsFlowCoordinator = PaymentsFlowCoordinator()

    @Dependency(\.windowService) private var windowService

    init(_ factory: Factory) {
        self.factory = factory
    }
}

extension IosAlertService: CoreAlertService {
    func push(alert: SystemAlert) {
        executeOnUIThread {
            MainActor.assumeIsolated {
                self.pushOnUIThread(alert: alert)
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    @MainActor
    func pushOnUIThread(alert: SystemAlert) {
        log.info("Showing alert: \(String(describing: type(of: alert)))", category: .ui)

        switch alert {
        case is AccountDeletionErrorAlert:
            showDefaultSystemAlert(alert)

        case is AccountDeletionWarningAlert:
            showDefaultSystemAlert(alert)

        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)

        case is UpgradeUnavailableAlert:
            showDefaultSystemAlert(alert)

        case is MaintenanceAlert:
            showDefaultSystemAlert(alert)

        case is ChangeProtocolDisconnectAlert:
            showDefaultSystemAlert(alert)

        case is LogoutWarningAlert:
            showDefaultSystemAlert(alert)

        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)

        case let connectionTroubleshootingAlert as ConnectionTroubleshootingAlert:
            show(connectionTroubleshootingAlert)

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)

        case is LANConnectionsKillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is KillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)

        case let announcementOfferAlert as AnnouncementOfferAlert:
            show(announcementOfferAlert)

        case let subuserAlert as SubuserWithoutConnectionsAlert:
            show(subuserAlert)

        case is ProtocolNotAvailableForServerAlert:
            showDefaultSystemAlert(alert)

        case let alert as UpgradeOperatingSystemAlert:
            showDefaultSystemAlert(alert)

        case let alert as DisconnectToSignInAlert:
            showDefaultSystemAlert(alert)

        case let alert as PaymentRestorationAlert:
            showDefaultSystemAlert(alert)

        default:
            if case .debug = BuildConfiguration.current {
                fatalError("Alert type handling not implemented: \(String(describing: alert))")
            } else {
                showDefaultSystemAlert(alert)
            }
        }
    }

    private func show(_ alert: AppUpdateRequiredAlert) {
        alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: { [weak self] in
            self?.appSessionManager.logOut(force: true, reason: nil)
        }))

        uiAlertService.displayAlert(alert)
    }

    private func show(_ alert: MaintenanceAlert) {
        switch alert.type {
        case .alert:
            showDefaultSystemAlert(alert)
        case .notification:
            showNotificationStyleAlert(message: alert.title ?? alert.message ?? "")
        }
    }

    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }

    private func showNotificationStyleAlert(message: String, type: NotificationStyleAlertType = .error, accessibilityIdentifier: String? = nil) {
        uiAlertService.displayNotificationStyleAlert(message: message, type: type, accessibilityIdentifier: accessibilityIdentifier)
    }

    private func show(_: ConnectionTroubleshootingAlert) {
        let controller = TroubleshootHostingViewController()
        windowService.present(modal: controller)
    }

    private func show(_ alert: AnnouncementOfferAlert) {
        guard let panelMode = alert.data.panelMode() else {
            log.warning("Couldn't determine panelMode from: \(alert.data)")
            return
        }
        let announcement: AnnouncementViewController
        switch panelMode {
        case let .legacy(legacyPanel):
            announcement = AnnouncementDetailViewController(legacyPanel)
            announcement.modalPresentationStyle = .fullScreen
        case let .image(imagePanel):
            announcement = AnnouncementImageViewController(data: imagePanel, offerReference: alert.offerReference)
            announcement.modalPresentationStyle = UIDevice.current.isIpad ? .pageSheet : .overFullScreen
        }
        announcement.cancelled = { [weak self] in
            self?.windowService.dismissModal {}
        }
        announcement.urlRequested = { url in
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)

            DispatchQueue.main.async {
                AppEvent.userEngagedWithAnnouncement.post(alert.offerReference)
            }
        }
        windowService.present(modal: announcement)
    }

    private func show(_ alert: SubuserWithoutConnectionsAlert) {
        let controller = UIHostingController(rootView: NoConnectionsAvailableView(mode: alert.mode))
        windowService.present(modal: controller)
    }

    @MainActor
    private func presentDirectSubscriptionManagement() {
        let viewController = paymentsFlowCoordinator.makeViewController(
            request: .directSubscriptionManagement
        ) { [weak self] event in
            guard let self else { return }
            switch event {
            case .completed, .dismissed:
                windowService.dismissModal(nil)
            case .engaged, .createAccountFirstRequested:
                break
            }
        }
        windowService.present(modal: viewController)
    }
}

private extension ReconnectInfo {
    func servers() -> (from: (String, UIImage), to: (String, UIImage)) {
        ((fromServer.name, fromServer.image), (toServer.name, toServer.image))
    }
}
