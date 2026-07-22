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
import Modals
import Strings
import SwiftUI
import VPNAppCore

final class IosAlertService {
    private lazy var uiAlertService = IosUiAlertService()
}

// MARK: - Live dependency

extension CoreAlertService: @retroactive DependencyKey {
    public static let liveValue = {
        let iosAlertService = IosAlertService()
        return CoreAlertService(push: { alert in
            iosAlertService.push(alert: alert)
        })
    }()
}

extension IosAlertService {
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

        case is AppUpdateRequiredAlert:
            showDefaultSystemAlert(alert)

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

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)

        case is LANConnectionsKillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is KillSwitchLogoutBlockingFailedAlert:
            showDefaultSystemAlert(alert)

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
}

private extension ReconnectInfo {
    func servers() -> (from: (String, UIImage), to: (String, UIImage)) {
        ((fromServer.name, fromServer.image), (toServer.name, toServer.image))
    }
}
