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
import Modals
import Modals_iOS
import UIKit

class IosAlertService {
        
    typealias Factory = UIAlertServiceFactory & AppSessionManagerFactory & WindowServiceFactory & SettingsServiceFactory & TroubleshootCoordinatorFactory & SafariServiceFactory & PlanServiceFactory
    private let factory: Factory
    
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var settingsService: SettingsService = factory.makeSettingsService()
    private lazy var safariService: SafariServiceProtocol = factory.makeSafariService()
    private lazy var upsell: Upsell = Upsell(factory)

    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var modalsFactory: ModalsFactory = ModalsFactory(colors: UpsellColors())
    
    init(_ factory: Factory) {
        self.factory = factory
    }
}

extension IosAlertService: CoreAlertService {
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    func push(alert: SystemAlert) {
        switch alert {
        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)
            
        case let cannotAccessVpnCredentialsAlert as CannotAccessVpnCredentialsAlert:
            show(cannotAccessVpnCredentialsAlert)
            
        case is ExistingConnectionAlert:
            showDefaultSystemAlert(alert)
            
        case is FirstTimeConnectingAlert:
            break // do nothing
            
        case is P2pBlockedAlert:
            showDefaultSystemAlert(alert)
            
        case is P2pForwardedAlert:
            showDefaultSystemAlert(alert)
            
        case let refreshTokenExpiredAlert as RefreshTokenExpiredAlert:
            show(refreshTokenExpiredAlert)
            
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

        case is BugReportSentAlert:
            showDefaultSystemAlert(alert)
            
        case is UnknownErrortAlert:
            showDefaultSystemAlert(alert)
            
        case is ApplyCreditAfterRegistrationFailedAlert:
            showDefaultSystemAlert(alert)
            
        case let reportBugAlert as ReportBugAlert:
            show(reportBugAlert)

        case is MITMAlert:
            showDefaultSystemAlert(alert)

        case is InvalidHumanVerificationCodeAlert:
            showDefaultSystemAlert(alert)
            
        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)
            
        case is ConnectionTroubleshootingAlert:
            show(alert as! ConnectionTroubleshootingAlert)
            
        case is RegistrationUserAlreadyExistsAlert:
            showDefaultSystemAlert(alert)
            
        case is PaymentFailedAlert:
            showDefaultSystemAlert(alert)
            
        case is ReconnectOnNetshieldChangeAlert:
            showDefaultSystemAlert(alert)

        case let vpnServerOnMaintenanceAlert as VpnServerOnMaintenanceAlert:
            show(vpnServerOnMaintenanceAlert)

        case is VPNAuthCertificateRefreshErrorAlert:
            showDefaultSystemAlert(alert)
            
        case is UserAccountUpdateAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)
            
        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerErrorAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerSubscriptionErrorAlert:
            showDefaultSystemAlert(alert)

        case is WireguardProfileErrorAlert:
            showDefaultSystemAlert(alert)
            
        case is AllowLANConnectionsAlert:
            showDefaultSystemAlert(alert)
            
        case is TurnOnKillSwitchAlert:
            showDefaultSystemAlert(alert)
            
        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)

        case let announcementOfferAlert as AnnouncmentOfferAlert:
            show(announcementOfferAlert)
            
        case let subuserAlert as SubuserWithoutConnectionsAlert:
            show(subuserAlert)
            
        case is TooManyCertificateRequestsAlert:
            showDefaultSystemAlert(alert)

        case is SafeModeUpsellAlert:
            show(upsellType: .safeMode)

        case is NetShieldUpsellAlert:
            show(upsellType: .netShield)

        case is SecureCoreUpsellAlert:
            show(upsellType: .secureCore)

        case is ModerateNATUpsellAlert:
            show(upsellType: .moderateNAT)

        case is AllCountriesUpsellAlert:
            let plus = AccountPlan.plus
            let allCountriesUpsell = UpsellType.allCountries(numberOfDevices: plus.devicesCount, numberOfServers: plus.serversCount, numberOfCountries: plus.countriesCount)
            show(upsellType: allCountriesUpsell)
            
        default:
            #if DEBUG
            fatalError("Alert type handling not implemented: \(String(describing: alert))")
            #else
            showDefaultSystemAlert(alert)
            #endif
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    private func show(upsellType: Modals.UpsellType) {
        let upsellViewController = modalsFactory.upsellViewController(upsellType: upsellType)
        upsellViewController.delegate = self
        windowService.present(modal: upsellViewController)
    }
    
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
    
    private func show(_ alert: ConnectionTroubleshootingAlert) {
        factory.makeTroubleshootCoordinator().start()
    }
 
    private func show(_ alert: VpnServerOnMaintenanceAlert ) {
        showNotificationStyleAlert(message: alert.title ?? "", type: .success)
    }

    private func show(_ alert: AnnouncmentOfferAlert) {
        let vc = AnnouncementDetailViewController(alert.data)
        vc.modalPresentationStyle = .fullScreen
        vc.cancelled = { [weak self] in
            self?.windowService.dismissModal { }
        }
        vc.urlRequested = { [weak self] url in
            self?.safariService.open(url: url)
        }
        windowService.present(modal: vc)
    }

    private func show(_ alert: SubuserWithoutConnectionsAlert) {
        let storyboard = UIStoryboard(name: "SubuserAlertViewController", bundle: Bundle.main)
        guard let controller = storyboard.instantiateInitialViewController() as? SubuserAlertViewController else { return }
        controller.safariServiceFactory = factory
        windowService.present(modal: controller)
    }
}

extension IosAlertService: UpsellViewControllerDelegate {
    func shouldDismissUpsell() -> Bool {
        return true
    }

    func userDidRequestPlus() {
        windowService.dismissModal { [weak self] in
            self?.planService.presentPlanSelection()
        }
    }

    func userDidDismissUpsell() {
        windowService.dismissModal { }
    }
}
