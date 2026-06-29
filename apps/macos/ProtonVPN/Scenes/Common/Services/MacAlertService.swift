//
//  MacAlertService.swift
//  ProtonVPN - Created on 27/08/2019.
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
import AppKit
import BugReport
import Dependencies
import Domain
import Ergonomics
import Strings
import VPNAppCore
import VPNShared

final class MacAlertService {
    private lazy var uiAlertService = OsxUiAlertService()
    @Dependency(\.updateManager) private var updateManager
    @Dependency(\.linkOpener) var linkOpener
}

// MARK: - Live dependency

extension CoreAlertService: @retroactive DependencyKey {
    public static let liveValue = {
        let macAlertsService = MacAlertService()
        return CoreAlertService(push: { alert in
            macAlertsService.push(alert: alert)
        })
    }()
}

extension MacAlertService {
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
        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)

        // Actual Alerts

        case is MaintenanceAlert:
            showDefaultSystemAlert(alert)

        case is LogoutWarningAlert:
            showDefaultSystemAlert(alert)

        case is ClearApplicationDataAlert:
            showDefaultSystemAlert(alert)

        case is ActiveSessionWarningAlert:
            showDefaultSystemAlert(alert)

        case is QuitWarningAlert:
            showDefaultSystemAlert(alert)

        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)

        case is SysexInstallingErrorAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)

        case is IkeDeprecatedAlert:
            showDefaultSystemAlert(alert)

        case is KillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is LANConnectionsKillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is ProtonUnreachableAlert:
            showDefaultSystemAlert(alert)

        case is ProtocolNotAvailableForServerAlert:
            showDefaultSystemAlert(alert)

        case let alert as ForceUpgradeAlert:
            showDefaultSystemAlert(alert)

        case let alert as UpgradeOperatingSystemAlert:
            showDefaultSystemAlert(alert)

        case let alert as HermesSettingsViewAlert:
            showDefaultSystemAlert(alert)

        default:
            #if DEBUG
                fatalError("Alert type handling not implemented: \(String(describing: alert))")
            #else
                showDefaultSystemAlert(alert)
            #endif
        }
    }

    // MARK: Alerts UI

    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }

    private func show(_ alert: AppUpdateRequiredAlert) {
        let supportAction = AlertAction(title: Localizable.updateRequiredSupport, style: .confirmative) { [weak self] in
            self?.linkOpener.open(.supportForm)
        }
        let updateAction = AlertAction(title: Localizable.updateRequiredUpdate, style: .confirmative) {
            self.updateManager.startUpdate()
        }

        alert.actions.append(supportAction)
        alert.actions.append(updateAction)

        uiAlertService.displayAlert(alert)
    }
}
