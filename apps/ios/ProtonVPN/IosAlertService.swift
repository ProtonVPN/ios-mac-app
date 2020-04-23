//
//  IosCoreAlertService.swift
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

import Foundation
import vpncore

class IosAlertService {
    
    typealias Factory = UIAlertServiceFactory & AppSessionManagerFactory & HumanVerificationCoordinatorFactory & WindowServiceFactory & SettingsServiceFactory
    private let factory: Factory
    
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var settingsService: SettingsService = factory.makeSettingsService()
    
    init(_ factory: Factory) {
        self.factory = factory
    }
    
}

extension IosAlertService: CoreAlertService {
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    func push(alert: SystemAlert) {
        switch alert {
        case is AppUpdateRequiredAlert:
            show(alert as! AppUpdateRequiredAlert)
            
        case is CannotAccessVpnCredentialsAlert:
            show(alert as! CannotAccessVpnCredentialsAlert)
            
        case is ExistingConnectionAlert:
            showDefaultSystemAlert(alert)
            
        case is FirstTimeConnectingAlert:
            break // do nothing
            
        case is P2pBlockedAlert:
            showDefaultSystemAlert(alert)
            
        case is P2pForwardedAlert:
            showDefaultSystemAlert(alert)
            
        case is RefreshTokenExpiredAlert:
            show(alert as! RefreshTokenExpiredAlert)
            
        case is UpgradeRequiredAlert:
            showDefaultSystemAlert(alert)
            
        case is UpgradeUnavailableAlert:
            showDefaultSystemAlert(alert)
            
        case is DelinquentUserAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnStuckAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnNetworkUnreachableAlert:
            showNotificationStyleAlert(message: alert.title ?? alert.message ?? "")
            
        case is SessionCountLimitAlert:
            showDefaultSystemAlert(alert)
            
        case is StoreKitErrorAlert:
            showDefaultSystemAlert(alert)
            
        case is StoreKitUserValidationByPassAlert:
            showDefaultSystemAlert(alert)
            
        case is MaintenanceAlert:
            showDefaultSystemAlert(alert)
            
        case is SecureCoreToggleDisconnectAlert:
            showDefaultSystemAlert(alert)
            
        case is ChangeProtocolDisconnectAlert:
            showDefaultSystemAlert(alert)
            
        case is LogoutWarningAlert:
            showDefaultSystemAlert(alert)
                        
        case is TrialExpiredAlert:
            showDefaultSystemAlert(alert)
            
        case is BugReportSentAlert:
            showDefaultSystemAlert(alert)
            
        case is UnknownErrortAlert:
            showDefaultSystemAlert(alert)
            
        case is PlanPurchaseErrorAlert:
            if alert.title != nil {
                showDefaultSystemAlert(alert)
            } else {
                showNotificationStyleAlert(message: alert.message ?? "")
            }
        case is UserVerificationAlert:
            show(alert as! UserVerificationAlert)
            
        case is ErrorNotificationAlert:
            showNotificationStyleAlert(message: alert.message ?? "", type: .error, accessibilityIdentifier: (alert as! ErrorNotificationAlert).accessibilityIdentifier)
            
        case is SuccessNotificationAlert:
            showNotificationStyleAlert(message: alert.message ?? "", type: .success)            
            
        case is ApplyCreditAfterRegistrationFailedAlert:
            showDefaultSystemAlert(alert)
            
        case is ReportBugAlert:
            show(alert as! ReportBugAlert)

        case is MITMAlert:
            showDefaultSystemAlert(alert)

        case is InvalidHumanVerificationCodeAlert:
            showDefaultSystemAlert(alert)
            
        default:
            #if DEBUG
            fatalError("Alert type handling not implemented: \(String(describing: alert))")
            #else
            showDefaultSystemAlert(alert)
            #endif
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    private func show(_ alert: AppUpdateRequiredAlert) {
        alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: { [weak self] in
            self?.appSessionManager.logOut(force: true)
        }))
        
        uiAlertService.displayAlert(alert)
    }
    
    private func show(_ alert: CannotAccessVpnCredentialsAlert) {
        guard appSessionManager.sessionStatus == .established else { return } // already logged out
        self.appSessionManager.logOut(force: true)
        showDefaultSystemAlert(alert)
    }
    
    private func show(_ alert: RefreshTokenExpiredAlert) {
        alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: { [weak self] in
            self?.appSessionManager.logOut(force: true)
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
    
    private func show(_ alert: UserVerificationAlert) {
        let coordinator = factory.makeHumanVerificationCoordinator(verificationMethods: alert.verificationMethods, startingErrorMessage: alert.message, success: alert.success, failure: alert.failure)
        coordinator.finished = {
            self.windowService.dismissModal()
        }
        coordinator.start()
    }
    
    private func show(_ alert: ReportBugAlert) {
        settingsService.presentReportBug()
    }
    
    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        guard Thread.isMainThread else { return DispatchQueue.main.async { self.showDefaultSystemAlert(alert) } }
        
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: nil))
        }
        self.uiAlertService.displayAlert(alert)
    }
    
    private func showNotificationStyleAlert(message: String, type: NotificationStyleAlertType = .error, accessibilityIdentifier: String? = nil) {
        uiAlertService.displayNotificationStyleAlert(message: message, type: type, accessibilityIdentifier: accessibilityIdentifier)
    }
}
