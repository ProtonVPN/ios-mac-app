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

import Foundation
import vpncore
import AppKit

class MacAlertService {
    
    typealias Factory = UIAlertServiceFactory & AppSessionManagerFactory & WindowServiceFactory & NotificationManagerFactory & UpdateManagerFactory & PropertiesManagerFactory & TroubleshootViewModelFactory
    private let factory: Factory
    
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var notificationManager: NotificationManagerProtocol = factory.makeNotificationManager()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    fileprivate var lastTimeCheckMaintenance = Date(timeIntervalSince1970: 0)
    
    init(factory: Factory) {
        self.factory = factory
    }
    
}

extension MacAlertService: CoreAlertService {
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    func push(alert: SystemAlert) {
        guard Thread.isMainThread else { // Protects from running UI code on background threads
            DispatchQueue.main.async {
                self.push(alert: alert)
            }
            return
        }
        
        switch alert {
        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)
            
        case let cannotAccessVpnCredentialsAlert as CannotAccessVpnCredentialsAlert:
            show(cannotAccessVpnCredentialsAlert)
            
        case is ExistingConnectionAlert:
            showDefaultSystemAlert(alert)
            
        case let firstTimeConnectingAlert as FirstTimeConnectingAlert:
            // Neagent popup is no longer an issue in macOS 10.15+, so we don't need to show the help anymore
            if #available(OSX 10.15, *) {
                // do nothing
            } else {
                show(firstTimeConnectingAlert)
            }
            
        case is P2pBlockedAlert:
            showDefaultSystemAlert(alert)
            
        case let p2pForwardedAlert as P2pForwardedAlert:
            show(p2pForwardedAlert)
            
        case let refreshTokenExpiredAlert as RefreshTokenExpiredAlert:
            show(refreshTokenExpiredAlert)
            
        case let upgradeRequiredAlert as UpgradeRequiredAlert:
            show(upgradeRequiredAlert)
            
        case is DelinquentUserAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnStuckAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnNetworkUnreachableAlert:
            showDefaultSystemAlert(alert)
            
        case is SessionCountLimitAlert:
            showDefaultSystemAlert(alert)
            
        case is StoreKitErrorAlert:
            showDefaultSystemAlert(alert)
            
        case is StoreKitUserValidationByPassAlert:
            showDefaultSystemAlert(alert)
            
        case is MaintenanceAlert:
            showDefaultSystemAlert(alert)
            
        case is LogoutWarningAlert:
            showDefaultSystemAlert(alert)
            
        case is BugReportSentAlert:
            showDefaultSystemAlert(alert)
            
        case is UnknownErrortAlert:
            showDefaultSystemAlert(alert)

        case is MITMAlert:
            showDefaultSystemAlert(alert)            
            
        case let killSwitchRequiresSwift5Alert as KillSwitchRequiresSwift5Alert:
            show(killSwitchRequiresSwift5Alert)           
            
        case is ClearApplicationDataAlert:
            showDefaultSystemAlert(alert)
            
        case is ActiveSessionWarningAlert:
            showDefaultSystemAlert(alert)
            
        case is QuitWarningAlert:
            showDefaultSystemAlert(alert)

        case is SecureCoreToggleDisconnectAlert:
            showDefaultSystemAlert(alert)
            
        case let vpnServerOnMaintenanceAlert as VpnServerOnMaintenanceAlert:
            show(vpnServerOnMaintenanceAlert)
            
        case is ReconnectOnNetshieldChangeAlert:
            showDefaultSystemAlert(alert)
            
        case is NetShieldRequiresUpgradeAlert:
            showDefaultSystemAlert(alert)
            
        case is SecureCoreRequiresUpgradeAlert:
            showDefaultSystemAlert(alert)

        case let connectionTroubleshootingAlert as ConnectionTroubleshootingAlert:
            show(connectionTroubleshootingAlert)

        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)
            
        case is SysexInstallationRequiredAlert:
            showDefaultSystemAlert(alert)
            
        case is SysexEnabledAlert:
            showDefaultSystemAlert(alert)
            
        case is SysexInstallingErrorAlert:
            showDefaultSystemAlert(alert)
            
        case let systemExtensionTourAlert as SystemExtensionTourAlert:
            show(systemExtensionTourAlert)
            
        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)
            
        case let verificationAlert as UserVerificationAlert:
            show(verificationAlert)
            
        case is UserAccountUpdateAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)
            
        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)
            
        case is TurnOnKillSwitchAlert:
            showDefaultSystemAlert(alert)
            
        case is AllowLANConnectionsAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerErrorAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerSubscriptionErrorAlert:
            showDefaultSystemAlert(alert)

        case is WireguardProfileErrorAlert:
            showDefaultSystemAlert(alert)
            
        case is VPNAuthCertificateRefreshErrorAlert:
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

    // MARK: Alerts UI
    
    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }
    
    // MARK: Custom Alerts
    
    private func show(_ alert: AppUpdateRequiredAlert) {
        let supportAction = AlertAction(title: LocalizedString.updateRequiredSupport, style: .confirmative) {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.supportForm)
        }
        let updateAction = AlertAction(title: LocalizedString.updateRequiredUpdate, style: .confirmative) {
            self.updateManager.startUpdate()
        }
        
        alert.actions.append(supportAction)
        alert.actions.append(updateAction)
        
        uiAlertService.displayAlert(alert)
    }
    
    private func show(_ alert: CannotAccessVpnCredentialsAlert) {
        guard appSessionManager.sessionStatus == .established else { // already logged out
            return
        }
        self.appSessionManager.logOut(force: true)
        showDefaultSystemAlert(alert)
    }
    
    private func show(_ alert: FirstTimeConnectingAlert) {
        let neagentViewController = NeagentHelpPopUpViewController()
        windowService.presentKeyModal(viewController: neagentViewController)
    }

    private func show(_ alert: SystemExtensionTourAlert) {
        let viewModel = SystemExtensionGuideViewModel(extensionsCount: alert.extensionsCount, isTimeToClose: alert.isTimeToClose, acceptedHandler: alert.continueHandler)
        windowService.openSystemExtensionGuideWindow(viewModel: viewModel)
    }
    
    private func show(_ alert: P2pForwardedAlert) {
        guard let p2pIcon = NSAttributedString.imageAttachment(named: "p2p-white", width: 15, height: 12) else { return }
        
        let bodyP1 = (LocalizedString.p2pForwardedPopupBodyP1 + " ").attributed(withColor: .protonWhite(), fontSize: 14, alignment: .natural)
        let bodyP2 = (" " + LocalizedString.p2pForwardedPopupBodyP2).attributed(withColor: .protonWhite(), fontSize: 14, alignment: .natural)
        let body = NSAttributedString.concatenate(bodyP1, p2pIcon, bodyP2)
        
        alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: nil))
        
        uiAlertService.displayAlert(alert, message: body)
    }
    
    private func show(_ alert: RefreshTokenExpiredAlert) {
        let logoutAction = AlertAction(title: LocalizedString.ok, style: .confirmative, handler: { 
            self.appSessionManager.logOut(force: true)
        })
        alert.actions.append(logoutAction)
            
        uiAlertService.displayAlert(alert)
    }
    
    private func show(_ alert: UpgradeRequiredAlert) {
        let buttonPressed = alert.actions.first?.handler ?? {}
        switch alert.serverType {
        case .secureCore:
            let upgradeViewModel = SCUpgradePopUpViewModel(buttonPressed: buttonPressed)
            windowService.presentKeyModal(viewController: SCUpgradePopupViewController(viewModel: upgradeViewModel))
        default:
            alert.message = alert.forSpecificCountry ? LocalizedString.upgradePlanToAccessCountry : LocalizedString.upgradePlanToAccessServer
            presentStandardUpgradePopUp(alert, buttonPressed: buttonPressed)
        }
    }
    
    private func presentStandardUpgradePopUp(_ alert: UpgradeRequiredAlert, buttonPressed: (() -> Void)?) {
        let upgradeAction = AlertAction(title: LocalizedString.upgrade, style: .confirmative, handler: {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
            buttonPressed?()
        })
        alert.title = LocalizedString.upgradeRequired
        alert.actions.append(upgradeAction)
        
        uiAlertService.displayAlert(alert)
    }
    
    private func show( _ alert: KillSwitchRequiresSwift5Alert ) {
        let killSwitch5ViewController = KillSwitchSwift5Popup()
        killSwitch5ViewController.alert = alert
        windowService.presentKeyModal(viewController: killSwitch5ViewController)
    }
    
    private func show(_ alert: VpnServerOnMaintenanceAlert) {
        guard self.lastTimeCheckMaintenance.timeIntervalSinceNow < -AppConstants.Time.maintenanceMessageTimeThreshold else {
            return
        }
        self.notificationManager.displayServerGoingOnMaintenance()
        self.lastTimeCheckMaintenance = Date()
    }

    private func show(_ alert: ConnectionTroubleshootingAlert) {
        let connectionTroubleshootingAlert = TroubleshootingPopup()
        connectionTroubleshootingAlert.viewModel = factory.makeTroubleshootViewModel()
        windowService.presentKeyModal(viewController: connectionTroubleshootingAlert)
    }
    
    private func show( _ alert: UserVerificationAlert) {
        alert.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: {
            alert.failure(alert.error)
        }))
        showDefaultSystemAlert(alert)
    }
}
