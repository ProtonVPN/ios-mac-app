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
        present(alert)
    }
    
    func displayAlert(_ alert: SystemAlert, message: NSAttributedString) {
        present(alert, message: message)
    }
    
    func displayNotificationStyleAlert(message: String, type: NotificationStyleAlertType, accessibilityIdentifier: String?) {
        fatalError("Notification syle alerts unsupported on macOS")
    }
    
    private func present( _ alert: SystemAlert, message: NSAttributedString? = nil ) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }
        
        currentAlerts.append(alert)
        
        var modalVC: NSViewController!
        
        switch alert {
        case is ExpandableSystemAlert:
            let expandableViewModel = ExpandablePopupViewModel(alert as! ExpandableSystemAlert)
            expandableViewModel.dismissViewController = dismissCompletion(alert)
            alert.dismiss = { expandableViewModel.close() }
            modalVC = ExpandableContentPopupViewController(viewModel: expandableViewModel)
        default:
            let popUp = message == nil ? PopUpViewModel(alert: alert, inAppLinkManager: InAppLinkManager(navigationService: navigationService)) :
            PopUpViewModel(alert: alert, attributedDescription: message!, inAppLinkManager: InAppLinkManager(navigationService: navigationService))
            popUp.dismissCompletion = dismissCompletion(alert)
            alert.dismiss = { popUp.close() }
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
