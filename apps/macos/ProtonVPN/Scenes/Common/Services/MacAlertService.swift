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
import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Modals
import Payments
import Strings
import Theme
import VPNAppCore
import VPNShared

final class MacAlertService {
    typealias Factory =
        NavigationServiceFactory &
        UIAlertServiceFactory &
        WindowServiceFactory

    private let factory: Factory

    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var windowService: WindowService = factory.makeWindowService()
    @Dependency(\.updateManager) private var updateManager
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.linkOpener) var linkOpener

    init(factory: Factory) {
        self.factory = factory
    }
}

extension MacAlertService: CoreAlertService {
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

        case let alert as IkeDeprecatedAlert:
            show(alert)

        case let connectionTroubleshootingAlert as ConnectionTroubleshootingAlert:
            show(connectionTroubleshootingAlert)

        case let sysexAlert as SysexEnabledAlert:
            show(sysexAlert)

        case let systemExtensionTourAlert as SystemExtensionTourAlert:
            show(systemExtensionTourAlert)

        case let announcementOfferAlert as AnnouncementOfferAlert:
            show(announcementOfferAlert)

        case let subuserAlert as SubuserWithoutConnectionsAlert:
            show(subuserAlert)

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

    // MARK: Custom controllers that treated as Alerts

    private func show(_: SysexEnabledAlert) {
        @Dependency(\.defaultsProvider) var provider
        guard !provider.getDefaults().bool(forKey: AppConstants.UserDefaults.welcomed),
              let credentials = try? vpnKeychain.fetchCached()
        else {
            return
        }

        let welcomeViewController = WelcomeViewController(windowService: windowService)
        windowService.presentKeyModal(viewController: welcomeViewController, activatingApp: false)

        provider.getDefaults().set(true, forKey: AppConstants.UserDefaults.welcomed)
    }

    private func show(_ alert: SystemExtensionTourAlert) {
        windowService.openSystemExtensionGuideWindow(
            origin: alert.origin,
            cancelledHandler: alert.cancelHandler
        )
    }

    private func show(_: ConnectionTroubleshootingAlert) {
        let connectionTroubleshootingAlert = TroubleshootHostingViewController()
        windowService.presentKeyModal(viewController: connectionTroubleshootingAlert, activatingApp: false)
    }

    private func show(_ alert: AnnouncementOfferAlert) {
        guard let panelMode = alert.data.panelMode() else {
            log.warning("Couldn't determine panelMode from: \(alert.data)")
            return
        }
        let vc: NSViewController = switch panelMode {
        case let .legacy(legacyPanel):
            AnnouncementDetailViewController(legacyPanel)
        case let .image(imagePanel):
            AnnouncementImageViewController(
                data: imagePanel,
                offerReference: alert.offerReference
            )
        }

        windowService.presentKeyModal(viewController: vc, activatingApp: alert.activatingApp)
    }

    private func show(_ alert: SubuserWithoutConnectionsAlert) {
        windowService.openSubuserAlertWindow(alert: alert)
    }

    private func show(_ alert: IkeDeprecatedAlert) {
        let vc = ProtocolDeprecatedViewController(viewModel: WarningPopupViewModel(alert: alert))
        windowService.presentKeyModal(viewController: vc, activatingApp: alert.activatingApp)
    }
}
