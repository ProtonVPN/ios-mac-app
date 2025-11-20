//
//  OsxUiAlertService.swift
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
import LegacyCommon
import VPNAppCore

protocol UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService
}

class OsxUiAlertService: UIAlertService {
    typealias Factory = NavigationServiceFactory & WindowServiceFactory

    private let factory: Factory
    private lazy var navigationService: NavigationService = factory.makeNavigationService()

    private var windowService: WindowService
    private var currentAlerts = [SystemAlert]()

    public init(factory: Factory) {
        self.factory = factory
        self.windowService = factory.makeWindowService()
    }

    func displayAlert(_ alert: SystemAlert) {
        present(alert)
    }

    func displayAlert(_ alert: SystemAlert, message: NSAttributedString) {
        present(alert, message: message)
    }

    func displayNotificationStyleAlert(message _: String, type _: NotificationStyleAlertType, accessibilityIdentifier _: String?) {
        fatalError("Notification syle alerts unsupported on macOS")
    }

    private func present(_ alert: SystemAlert, message: NSAttributedString? = nil) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }

        currentAlerts.append(alert)

        let modalVC: NSViewController

        switch alert {
        case let userAccountUpdateAlert as UserAccountUpdateAlert:
            let userUpdateVC = UserAccountUpdateViewController(alert: userAccountUpdateAlert)
            alert.dismiss = { [weak self] in self?.dismissCompletion(alert) }
            modalVC = userUpdateVC
        case let expandableSystemAlert as ExpandableSystemAlert:
            let expandableViewModel = ExpandablePopupViewModel(expandableSystemAlert)
            expandableViewModel.dismissViewController = { [weak self] in self?.dismissCompletion(alert) }
            alert.dismiss = { [weak expandableViewModel] in expandableViewModel?.close() }
            modalVC = ExpandableContentPopupViewController(viewModel: expandableViewModel)
        default:
            let popUp = if let message {
                PopUpViewModel(alert: alert, attributedDescription: message, inAppLinkManager: InAppLinkManager(navigationService: navigationService))
            } else {
                PopUpViewModel(alert: alert, inAppLinkManager: InAppLinkManager(navigationService: navigationService))
            }
            popUp.dismissCompletion = { [weak self] in self?.dismissCompletion(alert) }
            alert.dismiss = { [weak popUp] in popUp?.close() }
            modalVC = PopUpViewController(viewModel: popUp)
        }

        if alert.displayOnActiveScreen, UserDefaults.standard.bool(forKey: AppConstants.UserDefaults.displayAlertsOnActiveScreen) {
            windowService.presentKeyModalOnActiveScreen(viewController: modalVC, activatingApp: alert.activatingApp)
        } else {
            windowService.presentKeyModal(viewController: modalVC, activatingApp: alert.activatingApp)
        }
    }

    private func alertIsNew(_ alert: SystemAlert) -> Bool {
        !currentAlerts.contains(where: { currentAlert -> Bool in
            return currentAlert.className == alert.className
        })
    }

    private func updateOldAlert(with newAlert: SystemAlert) {
        let oldAlert = currentAlerts.first { alert -> Bool in
            return alert.className == newAlert.className
        }

        // In particular this means the alert's completion handlers will be updated
        oldAlert?.actions = newAlert.actions
    }

    private func dismissCompletion(_ alert: SystemAlert) {
        currentAlerts.removeAll { currentAlert in
            currentAlert.className == alert.className
        }
    }
}
