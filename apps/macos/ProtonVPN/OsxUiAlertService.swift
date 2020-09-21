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

import Foundation
import vpncore

protocol UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService
}

class OsxUiAlertService: UIAlertService {
    
    typealias Factory = WindowServiceFactory & NavigationServiceFactory
    
    private let factory: Factory
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    
    private var windowService: WindowService
    private var currentAlerts = [SystemAlert]()
    
    public init(factory: Factory) {
        self.factory = factory
        windowService = factory.makeWindowService()
    }
    
    func displayAlert(_ alert: SystemAlert) {
        let viewModel = PopUpViewModel(alert: alert, inAppLinkManager: InAppLinkManager(navigationService: navigationService))
        present(viewModel, alert: alert)
    }
    
    func displayAlert(_ alert: SystemAlert, message: NSAttributedString) {
        let viewModel = PopUpViewModel(alert: alert, attributedDescription: message, inAppLinkManager: InAppLinkManager(navigationService: navigationService))
        present(viewModel, alert: alert)
    }
    
    func displayNotificationStyleAlert(message: String, type: NotificationStyleAlertType, accessibilityIdentifier: String?) {
        fatalError("Notification syle alerts unsupported on macOS")
    }
    
    private func present(_ popUp: PopUpViewModel, alert: SystemAlert) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }
        
        currentAlerts.append(alert)
        
        popUp.dismissCompletion = dismissCompletion(alert)
        alert.dismiss = {
            popUp.close()
        }
        
        var modalVC: NSViewController!
        
        switch alert {
        case is KillSwitchErrorAlert:
            modalVC = ExpandableContentPopup()
        default:
            modalVC = PopUpViewController(viewModel: popUp)
        }
        
        windowService.presentKeyModal(viewController: modalVC)
    }
    
    private func alertIsNew(_ alert: SystemAlert) -> Bool {
        return !currentAlerts.contains(where: { (currentAlert) -> Bool in
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
    
    private func dismissCompletion(_ alert: SystemAlert) -> (() -> Void) {
        return { [weak self] in
            self?.currentAlerts.removeAll { currentAlert in
                return currentAlert.className == alert.className
            }
        }
    }
    
}
