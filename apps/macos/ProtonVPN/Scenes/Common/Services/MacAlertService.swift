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

import AppKit
import Foundation

import Dependencies

import CommonNetworking
import LegacyCommon
import VPNAppCore
import VPNShared

import Announcement
import Modals

import Domain
import Ergonomics
import Strings
import Theme

final class MacAlertService {
    @Dependency(\.serverRepository) var serverRepository

    typealias Factory =
        AppSessionManagerFactory &
        NavigationServiceFactory &
        NotificationManagerFactory &
        PropertiesManagerFactory &
        TelemetrySettingsFactory &
        TroubleshootViewModelFactory & UIAlertServiceFactory &
        UpdateManagerFactory &
        VpnKeychainFactory &
        WindowServiceFactory

    private let factory: Factory

    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var notificationManager: NotificationManagerProtocol = factory.makeNotificationManager()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    private lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    @Dependency(\.sessionService) var sessionService
    @Dependency(\.linkOpener) var linkOpener

    private var lastTimeCheckMaintenance = Date(timeIntervalSince1970: 0)

    init(factory: Factory) {
        self.factory = factory
    }
}

public final class NEKSOnT2Alert: SystemAlert {
    public var title: String? = Localizable.neksT2Title
    public var message: String? = Localizable.neksT2Description
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?

    public let link = Localizable.neksT2Hyperlink
    public let killSwitchOffAction: AlertAction
    public let connectAnywayAction: AlertAction

    public init(killSwitchOffHandler: @escaping () -> Void, connectAnywayHandler: @escaping () -> Void) {
        self.killSwitchOffAction = AlertAction(title: Localizable.wgksKsOff, style: .confirmative, handler: killSwitchOffHandler)
        self.connectAnywayAction = AlertAction(title: Localizable.neksT2Connect, style: .destructive, handler: connectAnywayHandler)
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
        log.info("Showing alert: \(String(describing: type(of: alert)))", category: .ui)

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
            let allCountriesUpsell = ModalType.allCountries(
                numberOfServers: serverRepository.roundedServerCount,
                numberOfCountries: serverRepository.countryCount()
            )
            show(alert: alert, modalType: allCountriesUpsell)

        case let alert as ModerateNATUpsellAlert:
            show(alert: alert, modalType: .moderateNAT)

        case let alert as SafeModeUpsellAlert:
            show(alert: alert, modalType: .safeMode)

        case let alert as SecureCoreUpsellAlert:
            show(alert: alert, modalType: .secureCore)

        case let alert as NetShieldUpsellAlert:
            show(alert: alert, modalType: .netShield)

        case let alert as PortForwardingUpsellAlert:
            show(alert: alert, modalType: .portForwarding)

        case let alert as ProfilesUpsellAlert:
            show(alert: alert, modalType: .profiles)

        case let alert as VPNAcceleratorUpsellAlert:
            show(alert: alert, modalType: .vpnAccelerator)

        case let alert as CustomizationUpsellAlert:
            show(alert: alert, modalType: .customization)

        case let alert as CountryUpsellAlert:
            let countryModal = ModalType.country(
                countryFlag: .flag(countryCode: alert.countryCode) ?? Image(),
                numberOfDevices: DomainConstants.maxDeviceCount,
                numberOfCountries: serverRepository.countryCount()
            )
            show(alert: alert, modalType: countryModal)

        case let alert as HermesUpsellAlert:
            show(alert: alert, modalType: .hermes)

        case let alert as PlutoniumUpsellAlert:
            show(alert: alert, modalType: .plutonium)

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

        case let alert as IkeDeprecatedAlert:
            show(alert)

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

        case is KillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is LANConnectionsKillSwitchConflictAlert:
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

        case is ProtocolNotAvailableForServerAlert:
            showDefaultSystemAlert(alert)

        case is LocationNotAvailableAlert:
            showDefaultSystemAlert(alert)

        case let alert as ProtocolDeprecatedAlert:
            show(alert)

        case let alert as IKEv2PlutoniumConflictAlert:
            showDefaultSystemAlert(alert)

        case is ConnectingWithBadLANAlert:
            showDefaultSystemAlert(alert)

        case let alert as ConnectionCooldownAlert:
            show(
                alert: alert,
                modalType: .cantSkip(before: alert.until, totalDuration: alert.duration, longSkip: alert.longSkip)
            )

        case let alert as FreeConnectionsAlert:
            show(alert)

        case let alert as ForceUpgradeAlert:
            showDefaultSystemAlert(alert)

        case let alert as UpgradeOperatingSystemAlert:
            showDefaultSystemAlert(alert)

        case let alert as DomainErrorAlert:
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

    // swiftlint:enable cyclomatic_complexity function_body_length

    // MARK: Alerts UI

    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }

    // MARK: Custom Alerts

    private func show(_: SysexEnabledAlert) {
        @Dependency(\.defaultsProvider) var provider
        guard !provider.getDefaults().bool(forKey: AppConstants.UserDefaults.welcomed),
              let credentials = try? vpnKeychain.fetchCached()
        else {
            return
        }

        let welcomeViewController = WelcomeViewController(windowService: windowService, telemetrySettings: telemetrySettings)
        windowService.presentKeyModal(viewController: welcomeViewController)

        provider.getDefaults().set(true, forKey: AppConstants.UserDefaults.welcomed)
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

    private func show(_: CannotAccessVpnCredentialsAlert) {
        guard appSessionManager.sessionStatus == .established else { return } // already logged out
        appSessionManager.logOut(force: true, reason: Localizable.errorSignInAgain)
    }

    private func show(_ alert: SystemExtensionTourAlert) {
        windowService.openSystemExtensionGuideWindow(
            origin: alert.origin,
            cancelledHandler: alert.cancelHandler
        )
    }

    private func show(_ alert: P2pForwardedAlert) {
        let p2pIcon = AppTheme.Icon.arrowsSwitch.asAttachment(size: .rect(width: 15, height: 12))

        let bodyP1 = (Localizable.p2pForwardedPopupBodyP1 + " ").styled(alignment: .natural)
        let bodyP2 = (" " + Localizable.p2pForwardedPopupBodyP2).styled(alignment: .natural)
        let body = NSAttributedString.concatenate(bodyP1, p2pIcon, bodyP2)

        alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))

        uiAlertService.displayAlert(alert, message: body)
    }

    private func show(_: RefreshTokenExpiredAlert) {
        appSessionManager.logOut(force: true, reason: Localizable.invalidRefreshTokenPleaseLogin)
    }

    private func show(_: VpnServerOnMaintenanceAlert) {
        guard lastTimeCheckMaintenance.timeIntervalSinceNow < -AppConstants.Time.maintenanceMessageTimeThreshold else {
            return
        }
        notificationManager.displayServerGoingOnMaintenance()
        lastTimeCheckMaintenance = Date()
    }

    private func show(_: ConnectionTroubleshootingAlert) {
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
                AppEvent.userEngagedWithUpsellAlert.post(modalSource)
                self?.linkOpener.open(url)
            }
        }

        AppEvent.upsellAlertWasDisplayed.post(modalSource)

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
        let vc: NSViewController = switch panelMode {
        case let .legacy(legacyPanel):
            AnnouncementDetailViewController(legacyPanel)
        case let .image(imagePanel):
            AnnouncementImageViewController(
                data: imagePanel,
                offerReference: alert.offerReference
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

    private func show(_ alert: IkeDeprecatedAlert) {
        let vc = ProtocolDeprecatedViewController(viewModel: WarningPopupViewModel(alert: alert))
        windowService.presentKeyModal(viewController: vc)
    }

    private func show(_ alert: FreeConnectionsAlert) {
        let upgradeAction: (() -> Void) = { [weak self] in
            Task { [weak self] in
                guard let url = await self?.sessionService.getPlanSession(mode: .upgrade) else {
                    return
                }
                linkOpener.open(url)
            }
        }
        let upsellViewController = ModalsFactory.freeConnectionsViewController(countries: alert.countries, upgradeAction: upgradeAction)
        windowService.presentKeyModal(viewController: upsellViewController)
    }

    private func welcomeScreenType(plan: WelcomeScreenAlert.Plan) -> ModalType {
        switch plan {
        case .fallback:
            .welcomeFallback
        case .unlimited:
            .welcomeUnlimited
        case let .plus(numberOfServers, numberOfDevices, numberOfCountries):
            .welcomePlus(
                numberOfServers: numberOfServers,
                numberOfDevices: numberOfDevices,
                numberOfCountries: numberOfCountries
            )
        }
    }
}
