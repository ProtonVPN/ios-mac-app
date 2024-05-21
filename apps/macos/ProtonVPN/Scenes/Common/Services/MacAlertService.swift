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
import Dependencies
import Ergonomics
import LegacyCommon
import AppKit
import Modals
import Modals_macOS
import VPNShared
import Theme
import Strings

final class MacAlertService {
    
    typealias Factory = UIAlertServiceFactory & AppSessionManagerFactory & WindowServiceFactory & NotificationManagerFactory & UpdateManagerFactory & TroubleshootViewModelFactory & PlanServiceFactory & SessionServiceFactory & TelemetrySettingsFactory & VpnKeychainFactory
    private let factory: Factory
    
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var notificationManager: NotificationManagerProtocol = factory.makeNotificationManager()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var sessionService: SessionService = factory.makeSessionService()
    private lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    
    private var lastTimeCheckMaintenance = Date(timeIntervalSince1970: 0)
    
    init(factory: Factory) {
        self.factory = factory
    }
    
}

extension MacAlertService: CoreAlertService {
    
    func push(alert: SystemAlert) {
        executeOnUIThread {
            self.pushOnUIThread(alert: alert)
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func pushOnUIThread(alert: SystemAlert) {
        log.debug("Alert shown: \(String(describing: type(of: alert)))", category: .ui)
        
        switch alert {
        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)
            
        case let cannotAccessVpnCredentialsAlert as CannotAccessVpnCredentialsAlert:
            show(cannotAccessVpnCredentialsAlert)

        case is P2pBlockedAlert:
            showDefaultSystemAlert(alert)
            
        case let p2pForwardedAlert as P2pForwardedAlert:
            show(p2pForwardedAlert)
            
        case let refreshTokenExpiredAlert as RefreshTokenExpiredAlert:
            show(refreshTokenExpiredAlert)

        case let alert as WelcomeScreenAlert:
            show(alert: alert, modalType: welcomeScreenType(plan: alert.plan))

        case let alert as AllCountriesUpsellAlert:
            let plus = AccountPlan.plus
            let countriesCount = planService.countriesCount
            let allCountriesUpsell = ModalType.allCountries(numberOfServers: plus.serversCount, numberOfCountries: countriesCount)
            show(alert: alert, modalType: allCountriesUpsell)

        case let alert as ModerateNATUpsellAlert:
            show(alert: alert, modalType: .moderateNAT)

        case let alert as SafeModeUpsellAlert:
            show(alert: alert, modalType: .safeMode)

        case let alert as SecureCoreUpsellAlert:
            show(alert: alert, modalType: .secureCore)

        case let alert as NetShieldUpsellAlert:
            show(alert: alert, modalType: .netShield)

        case let alert as ProfilesUpsellAlert:
            show(alert: alert, modalType: .profiles)

        case let alert as VPNAcceleratorUpsellAlert:
            show(alert: alert, modalType: .vpnAccelerator)

        case let alert as CustomizationUpsellAlert:
            show(alert: alert, modalType: .customization)

        case let alert as CountryUpsellAlert:
            let plus = AccountPlan.plus
            show(alert: alert, modalType: .country(countryFlag: alert.countryFlag,
                                                    numberOfDevices: plus.devicesCount,
                                                    numberOfCountries: planService.countriesCount))

        case let alert as DiscourageSecureCoreAlert:
            show(alert)

        case is DelinquentUserAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnStuckAlert:
            showDefaultSystemAlert(alert)
            
        case is VpnNetworkUnreachableAlert:
            showDefaultSystemAlert(alert)
            
        case is MaintenanceAlert:
            showDefaultSystemAlert(alert)
            
        case is LogoutWarningAlert:
            showDefaultSystemAlert(alert)
            
        case is BugReportSentAlert:
            showDefaultSystemAlert(alert)

        case is MITMAlert:
            showDefaultSystemAlert(alert)

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

        case let connectionTroubleshootingAlert as ConnectionTroubleshootingAlert:
            show(connectionTroubleshootingAlert)

        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)
            
        case let sysexAlert as SysexEnabledAlert:
            show(sysexAlert)
            
        case is SysexInstallingErrorAlert:
            showDefaultSystemAlert(alert)
            
        case let systemExtensionTourAlert as SystemExtensionTourAlert:
            show(systemExtensionTourAlert)
            
        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)

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
            
        case is VPNAuthCertificateRefreshErrorAlert:
            showDefaultSystemAlert(alert)

        case let announcementOfferAlert as AnnouncementOfferAlert:
            show(announcementOfferAlert)
            
        case let subuserAlert as SubuserWithoutConnectionsAlert:
            show(subuserAlert)
            
        case is TooManyCertificateRequestsAlert:
            showDefaultSystemAlert(alert)

        case let neKST2Alert as NEKSOnT2Alert:
            show(neKST2Alert)

        case is ProtonUnreachableAlert:
            showDefaultSystemAlert(alert)

        case is LocalAgentSystemErrorAlert:
            showDefaultSystemAlert(alert)

        case is ProtocolNotAvailableForServerAlert:
            showDefaultSystemAlert(alert)

        case let alert as ProtocolDeprecatedAlert:
            show(alert)

        case is ConnectingWithBadLANAlert:
            showDefaultSystemAlert(alert)

        case let alert as ConnectionCooldownAlert:
            show(
                alert: alert,
                modalType: .cantSkip(before: alert.until, duration: alert.duration, longSkip: alert.longSkip)
            )

        case let alert as FreeConnectionsAlert:
            show(alert)

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
            alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }
    
    // MARK: Custom Alerts

    private func show(_ alert: SysexEnabledAlert) {
        @Dependency(\.defaultsProvider) var provider
        guard !provider.getDefaults().bool(forKey: AppConstants.UserDefaults.welcomed),
              let credentials = try? self.vpnKeychain.fetchCached()
        else {
            return
        }

        let welcomeViewController = WelcomeViewController(telemetrySettings: telemetrySettings)
        windowService.presentKeyModal(viewController: welcomeViewController)

        provider.getDefaults().set(true, forKey: AppConstants.UserDefaults.welcomed)
    }
    
    private func show(_ alert: AppUpdateRequiredAlert) {
        let supportAction = AlertAction(title: Localizable.updateRequiredSupport, style: .confirmative) {
            SafariService().open(url: CoreAppConstants.ProtonVpnLinks.supportForm)
        }
        let updateAction = AlertAction(title: Localizable.updateRequiredUpdate, style: .confirmative) {
            self.updateManager.startUpdate()
        }
        
        alert.actions.append(supportAction)
        alert.actions.append(updateAction)
        
        uiAlertService.displayAlert(alert)
    }
    
    private func show(_ alert: CannotAccessVpnCredentialsAlert) {
        guard appSessionManager.sessionStatus == .established else { return } // already logged out
        appSessionManager.logOut(force: true, reason: Localizable.errorSignInAgain)
    }

    private func show(_ alert: SystemExtensionTourAlert) {
        windowService.openSystemExtensionGuideWindow(cancelledHandler: alert.cancelHandler)
    }
    
    private func show(_ alert: P2pForwardedAlert) {
        let p2pIcon = AppTheme.Icon.arrowsSwitch.asAttachment(size: .rect(width: 15, height: 12))
        
        let bodyP1 = (Localizable.p2pForwardedPopupBodyP1 + " ").styled(alignment: .natural)
        let bodyP2 = (" " + Localizable.p2pForwardedPopupBodyP2).styled(alignment: .natural)
        let body = NSAttributedString.concatenate(bodyP1, p2pIcon, bodyP2)
        
        alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        
        uiAlertService.displayAlert(alert, message: body)
    }
    
    private func show(_ alert: RefreshTokenExpiredAlert) {
        appSessionManager.logOut(force: true, reason: Localizable.invalidRefreshTokenPleaseLogin)
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

    private func show(alert: UpsellAlert, modalType: ModalType) {
        let modalSource = alert.modalSource

        let upgradeAction: (() -> Void) = { [weak self] in
            Task { [weak self] in
                guard let url = await self?.sessionService.getPlanSession(mode: .upgrade) else {
                    return
                }
                NotificationCenter.default.post(name: .userEngagedWithUpsellAlert, object: modalSource)
                SafariService.openLink(url: url)
            }
        }
        
        NotificationCenter.default.post(name: .upsellAlertWasDisplayed, object: modalSource)

        let upsellViewController = ModalsFactory.upsellViewController(
            modalType: modalType,
            upgradeAction: upgradeAction,
            continueAction: alert.continueAction
        )

        windowService.presentKeyModal(viewController: upsellViewController)
    }

    private func show(_ alert: AnnouncementOfferAlert) {
        guard let panelMode = alert.data.panelMode() else {
            log.warning("Couldn't determine panelMode from: \(alert.data)")
            return
        }
        let vc: NSViewController
        switch panelMode {
        case .legacy(let legacyPanel):
            vc = AnnouncementDetailViewController(legacyPanel)
        case .image(let imagePanel):
            vc = AnnouncementImageViewController(
                data: imagePanel,
                offerReference: alert.offerReference,
                sessionService: sessionService
            )
        }

        windowService.presentKeyModal(viewController: vc)
    }
    
    private func show(_ alert: SubuserWithoutConnectionsAlert) {
        windowService.openSubuserAlertWindow(alert: alert)
    }

    private func show(_ alert: DiscourageSecureCoreAlert) {
        let viewController = ModalsFactory.discourageSecureCoreViewController(onDontShowAgain: alert.onDontShowAgain, onActivate: alert.onActivate, onCancel: alert.dismiss, onLearnMore: alert.onLearnMore)
        windowService.presentKeyModal(viewController: viewController)
    }

    private func show(_ alert: NEKSOnT2Alert) {
        let vc = NET2WarningPopupViewController(viewModel: WarningPopupViewModel(alert: alert))
        windowService.presentKeyModal(viewController: vc)
    }

    private func show(_ alert: ProtocolDeprecatedAlert) {
        let vc = ProtocolDeprecatedViewController(viewModel: WarningPopupViewModel(alert: alert))
        windowService.presentKeyModal(viewController: vc)
    }

    private func show(_ alert: FreeConnectionsAlert) {
        let upgradeAction: (() -> Void) = { [weak self] in
            Task { [weak self] in
                guard let url = await self?.sessionService.getPlanSession(mode: .upgrade) else {
                    return
                }
                SafariService.openLink(url: url)
            }
        }
        let upsellViewController = ModalsFactory.freeConnectionsViewController(countries: alert.countries, upgradeAction: upgradeAction)
        windowService.presentKeyModal(viewController: upsellViewController)
    }

    private func welcomeScreenType(plan: WelcomeScreenAlert.Plan) -> ModalType {
        switch plan {
        case .fallback:
            return .welcomeFallback
        case .unlimited:
            return .welcomeUnlimited
        case let .plus(numberOfServers, numberOfDevices, numberOfCountries):
            return .welcomePlus(numberOfServers: numberOfServers,
                                numberOfDevices: numberOfDevices,
                                numberOfCountries: numberOfCountries)
        }
    }
}
