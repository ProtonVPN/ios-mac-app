//
//  UIAlertService.swift
//  ProtonVPN - Created on 01.07.19.
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
import UIKit
import LegacyCommon

final class IosUiAlertService: UIAlertService {
    
    private let windowService: WindowService
    private var currentAlerts = [SystemAlert]()
    
    init(windowService: WindowService) {
        self.windowService = windowService
    }
    
    func displayAlert(_ alert: SystemAlert) {
        guard alertIsNew(alert) else {
            updateOldAlert(with: alert)
            return
        }
        
        currentAlerts.append(alert)
        displayTrackedAlert(alert: alert)
    }
    
    func displayAlert(_ alert: SystemAlert, message: NSAttributedString) {
        alert.message = message.string
        displayAlert(alert)
    }
    
    func displayNotificationStyleAlert(message: String, type: NotificationStyleAlertType, accessibilityIdentifier: String?) {
        windowService.present(message: message, type: type.presentedMessageType, accessibilityIdentifier: accessibilityIdentifier)
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
    
    private func displayTrackedAlert(alert: SystemAlert) {
        let alertController = TrackedAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
        alert.actions.forEach { action in
            alertController.addAction(UIAlertAction(title: action.title, style: action.style.alertButtonStyle, handler: { _ in
                action.handler?()
            }))
        }
        
        alertController.dismissCompletion = self.dismissCompletion(alert)
        alert.dismiss = {
            alertController.dismiss(animated: true, completion: nil)
        }
        
        self.windowService.present(modal: alertController)
    }
}

extension PrimaryActionType {
    
    var alertButtonStyle: UIAlertAction.Style {
        switch self {
        case .confirmative, .secondary:
            return .default
        case .destructive:
            return .destructive
        case .cancel:
            return .cancel
        }
    }
}

extension NotificationStyleAlertType {
    var presentedMessageType: PresentedMessageType {
        switch self {
        case .error: return PresentedMessageType.error
        case .success: return PresentedMessageType.success
        }
    }
}
