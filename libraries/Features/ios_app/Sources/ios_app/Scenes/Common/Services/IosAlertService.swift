//
//  IosAlertService.swift
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
import SwiftUI
import UIKit

import Dependencies

import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations

import Announcement
import BugReport
import Domain
import Ergonomics
import LegacyCommon
import Modals
import Persistence
import Strings
import Telemetry
import Theme
import VPNAppCore

final class IosAlertService {
    typealias Factory =
        AppSessionManagerFactory &
        NavigationServiceFactory &
        SettingsServiceFactory &
        UIAlertServiceFactory

    private let factory: Factory

    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var settingsService: SettingsService = factory.makeSettingsService()
    private lazy var navigationService: NavigationService = factory.makeNavigationService()

    private lazy var modalsFactory = ModalsFactory()

    private var oneClickPayment: OneClickPayment?
    private var oneClickPaymentV2: OneClickPaymentV2?
    private var oneClickIapVC: UIViewController?

    @ConcurrentlyReadable private var upsellAlerts: [UUID: UpsellAlert] = [:]

    @Dependency(\.windowService) private var windowService
    @Dependency(\.planService) private var planService
    @Dependency(\.planServiceV2) private var planServiceV2

    init(_ factory: Factory) {
        self.factory = factory
    }
}

extension IosAlertService: CoreAlertService {
    func push(alert: SystemAlert) {
        executeOnUIThread {
            self.pushOnUIThread(alert: alert)
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func pushOnUIThread(alert: SystemAlert) {
        log.info("Showing alert: \(String(describing: type(of: alert)))", category: .ui)

        switch alert {
        case is AccountDeletionErrorAlert:
            showDefaultSystemAlert(alert)

        case is AccountDeletionWarningAlert:
            showDefaultSystemAlert(alert)

        case let appUpdateRequiredAlert as AppUpdateRequiredAlert:
            show(appUpdateRequiredAlert)

        case let cannotAccessVpnCredentialsAlert as CannotAccessVpnCredentialsAlert:
            show(cannotAccessVpnCredentialsAlert)

        case is P2pBlockedAlert:
            showDefaultSystemAlert(alert)

        case is P2pForwardedAlert:
            showDefaultSystemAlert(alert)

        case let refreshTokenExpiredAlert as RefreshTokenExpiredAlert:
            show(refreshTokenExpiredAlert)

        case is UpgradeUnavailableAlert:
            showDefaultSystemAlert(alert)

        case is UpgradeCreateAccountAlert:
            showDefaultSystemAlert(alert)

        case is DelinquentUserAlert:
            showDefaultSystemAlert(alert)

        case is VpnStuckAlert:
            showDefaultSystemAlert(alert)

        case is VpnNetworkUnreachableAlert:
            showNotificationStyleAlert(message: alert.title ?? alert.message ?? "")

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

        case let reportBugAlert as ReportBugAlert:
            show(reportBugAlert)

        case is MITMAlert:
            showDefaultSystemAlert(alert)

        case is UnreachableNetworkAlert:
            showDefaultSystemAlert(alert)

        case let connectionTroubleshootingAlert as ConnectionTroubleshootingAlert:
            show(connectionTroubleshootingAlert)

        case is ReconnectOnNetshieldChangeAlert:
            showDefaultSystemAlert(alert)

        case let vpnServerOnMaintenanceAlert as VpnServerOnMaintenanceAlert:
            show(vpnServerOnMaintenanceAlert)

        case is VPNAuthCertificateRefreshErrorAlert:
            showDefaultSystemAlert(alert)

        case let alert as UserAccountUpdateAlert:
            displayUserUpdateAlert(alert: alert)

        case is ReconnectOnSmartProtocolChangeAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnActionAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerErrorAlert:
            showDefaultSystemAlert(alert)

        case is VpnServerSubscriptionErrorAlert:
            showDefaultSystemAlert(alert)

        case is LANConnectionsKillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is KillSwitchConflictAlert:
            showDefaultSystemAlert(alert)

        case is ReconnectOnSettingsChangeAlert:
            showDefaultSystemAlert(alert)

        case let announcementOfferAlert as AnnouncementOfferAlert:
            show(announcementOfferAlert)

        case let subuserAlert as SubuserWithoutConnectionsAlert:
            show(subuserAlert)

        case is TooManyCertificateRequestsAlert:
            showDefaultSystemAlert(alert)

        case let discourageAlert as DiscourageSecureCoreAlert:
            show(discourageAlert)

        case let safeModeUpsell as SafeModeUpsellAlert:
            show(alert: safeModeUpsell, modalType: .safeMode)

        case let netShieldUpsell as NetShieldUpsellAlert:
            show(alert: netShieldUpsell, modalType: .netShield)

        case let secureCoreUpsell as SecureCoreUpsellAlert:
            show(alert: secureCoreUpsell, modalType: .secureCore)

        case let moderateNatUpsell as ModerateNATUpsellAlert:
            show(alert: moderateNatUpsell, modalType: .moderateNAT)

        case let allCountriesUpsell as AllCountriesUpsellAlert:
            @Dependency(\.serverRepository) var repository
            let allCountriesModalType = ModalType.allCountries(
                numberOfServers: repository.roundedServerCount,
                numberOfCountries: repository.countryCount()
            )
            show(alert: allCountriesUpsell, modalType: allCountriesModalType)

        case let profilesUpsell as ProfilesUpsellAlert:
            show(alert: profilesUpsell, modalType: .profiles)

        case let vpnAcceleratorUpsell as VPNAcceleratorUpsellAlert:
            show(alert: vpnAcceleratorUpsell, modalType: .vpnAccelerator)

        case let customizationUpsell as CustomizationUpsellAlert:
            show(alert: customizationUpsell, modalType: .customization)

        case let streamingUpsell as StreamingUpsellAlert:
            show(alert: streamingUpsell, modalType: .streaming)

        case let p2pUpsell as P2PUpsellAlert:
            show(alert: p2pUpsell, modalType: .p2pSupport)

        case let devicesUpsell as DevicesUpsellAlert:
            show(alert: devicesUpsell, modalType: .devices)

        case let torUpsell as TorUpsellAlert:
            show(alert: torUpsell, modalType: .torOverVPN)

        case let countryUpsell as CountryUpsellAlert:
            @Dependency(\.serverRepository) var repository
            show(
                alert: countryUpsell,
                modalType: .country(
                    countryFlag: .flag(countryCode: countryUpsell.countryCode) ?? ImageAsset.Image(),
                    numberOfDevices: DomainConstants.maxDeviceCount,
                    numberOfCountries: repository.countryCount()
                )
            )

        case let alert as WelcomeScreenAlert:
            showWelcomeScreen(welcomeScreenAlert: alert)

        case is ProtocolNotAvailableForServerAlert:
            showDefaultSystemAlert(alert)

        case is LocationNotAvailableAlert:
            showDefaultSystemAlert(alert)

        case is ProtocolDeprecatedAlert:
            showDefaultSystemAlert(alert)

        case is ConnectingWithBadLANAlert:
            showDefaultSystemAlert(alert)

        case let cooldownUpsell as ConnectionCooldownAlert:
            show(
                alert: cooldownUpsell,
                modalType: .cantSkip(
                    before: cooldownUpsell.until,
                    totalDuration: cooldownUpsell.duration,
                    longSkip: cooldownUpsell.longSkip
                )
            )

        case let alert as FreeConnectionsAlert:
            show(alert)

        case let alert as PaymentAlert:
            showDefaultSystemAlert(alert)

        case let alert as UpgradeOperatingSystemAlert:
            showDefaultSystemAlert(alert)

        case let alert as DomainErrorAlert:
            showDefaultSystemAlert(alert)

        case let alert as HermesUpsellAlert:
            show(alert: alert, modalType: .hermes)

        case let alert as DisconnectToSignInAlert:
            showDefaultSystemAlert(alert)

        case let alert as PaymentRestorationAlert:
            showDefaultSystemAlert(alert)

        default:
            if case .debug = BuildConfiguration.current {
                fatalError("Alert type handling not implemented: \(String(describing: alert))")
            } else {
                showDefaultSystemAlert(alert)
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    // This method translates the `UserAccountUpdateAlert` subclasses to specific feature types that the Modals module expects.
    private func displayUserUpdateAlert(alert: UserAccountUpdateAlert) {
        let server = alert.reconnectInfo?.servers()
        let viewModel: UserAccountUpdateViewModel
        switch alert {
        case is UserBecameDelinquentAlert:
            if let server {
                viewModel = .pendingInvoicesReconnecting(fromServer: server.from, toServer: server.to)
            } else {
                viewModel = .pendingInvoices
            }
        case is UserPlanDowngradedAlert:
            let countriesCount: Int = if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
                planServiceV2.countriesCount
            } else {
                planService.countriesCount
            }

            if let server {
                viewModel = .subscriptionDowngradedReconnecting(
                    numberOfCountries: countriesCount,
                    numberOfDevices: DomainConstants.maxDeviceCount,
                    fromServer: server.from,
                    toServer: server.to
                )
            } else {
                viewModel = .subscriptionDowngraded(
                    numberOfCountries: countriesCount,
                    numberOfDevices: DomainConstants.maxDeviceCount
                )
            }
        case let alert as MaxSessionsAlert:
            if alert.accountTier.isFreeTier {
                viewModel = .reachedDevicePlanLimit(planName: Localizable.plus, numberOfDevices: DomainConstants.maxDeviceCount)
            } else {
                viewModel = .reachedDeviceLimit
            }
        default:
            return
        }
        let onPrimaryButtonTap: (() -> Void)? = { [weak self] in
            guard let self else { return }
            if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
                Task {
                    await self.planServiceV2.presentSubscriptionManagement(alertService: self)
                }
            } else {
                planService.presentSubscriptionManagement(alertService: self)
            }
        }

        let viewController = modalsFactory.userAccountUpdateViewController(
            viewModel: viewModel,
            onPrimaryButtonTap: onPrimaryButtonTap
        )
        viewController.modalPresentationStyle = .overFullScreen
        windowService.present(modal: viewController)
    }

    private func showWelcomeScreen(welcomeScreenAlert: WelcomeScreenAlert) {
        let modalType: ModalType = switch welcomeScreenAlert.plan {
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
        let viewController = modalsFactory.modalViewController(modalType: modalType, primaryAction: { [weak self] in
            self?.windowService.dismissModal(nil)
            AppEvent.userDismissedWelcomeScreen.post()
        })
        viewController.modalPresentationStyle = .overFullScreen
        windowService.present(modal: viewController)
    }

    private func show(alert: UpsellAlert, modalType: Modals.ModalType) {
        let viewController: UIViewController
        if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
            let oneClickPaymentV2: OneClickPaymentV2
            do {
                oneClickPaymentV2 = try OneClickPaymentV2(
                    alertService: self,
                    windowService: windowService,
                    createAccountFirstClosure: { [weak self] in
                        guard let oneClickIapVC = self?.oneClickIapVC else { return }
                        self?.navigationService.presentSignUp(over: oneClickIapVC, flow: .credentiallessUpsell)
                    }
                )
            } catch {
                log.error("Unexpected payments error: \(error)")
                return
            }

            oneClickPaymentV2.completionHandler = { [weak self] completion in
                self?.windowService.dismissModal(nil)
                completion?()
            }

            viewController = modalsFactory.upsellViewControllerV2(
                modalType: modalType,
                client: oneClickPaymentV2.plansClient(
                    validationHandler: { planOption, composedPlan in
                        let upsellData: UpsellData = if planOption.purchaseType == .web {
                            .webIntro(modalSource: alert.modalSource, newPlanName: composedPlan?.plan.name)
                        } else {
                            .init(
                                modalSource: alert.modalSource,
                                newPlanName: composedPlan?.plan.name,
                                reference: nil,
                                cycle: nil,
                                flowType: .oneClick
                            )
                        }
                        AppEvent.userEngagedWithUpsellAlert.post(upsellData)
                    },
                    notNowHandler: { [weak self] in
                        self?.windowService.dismissModal(nil)
                    }
                )
            )
            self.oneClickPaymentV2 = oneClickPaymentV2
        } else {
            let oneClickPayment: OneClickPayment
            do {
                oneClickPayment = try OneClickPayment(
                    alertService: self,
                    windowService: windowService,
                    createAccountFirstClosure: { [weak self] in
                        guard let oneClickIapVC = self?.oneClickIapVC else { return }
                        self?.navigationService.presentSignUp(over: oneClickIapVC, flow: .credentiallessUpsell)
                    }
                )
            } catch {
                log.error("Unexpected payments error: \(error)")
                return
            }

            oneClickPayment.completionHandler = { [weak self] in
                self?.windowService.dismissModal(nil)
            }

            viewController = modalsFactory.upsellViewController(
                modalType: modalType,
                client: oneClickPayment.plansClient(
                    validationHandler: { planOption, iapPlan in
                        let upsellData: UpsellData = if planOption.purchaseType == .web {
                            .webIntro(modalSource: alert.modalSource, newPlanName: iapPlan?.protonName)
                        } else {
                            .init(
                                modalSource: alert.modalSource,
                                newPlanName: iapPlan?.protonName,
                                reference: nil,
                                cycle: nil,
                                flowType: .oneClick
                            )
                        }
                        AppEvent.userEngagedWithUpsellAlert.post(upsellData)
                    },
                    notNowHandler: { [weak self] in
                        self?.windowService.dismissModal(nil)
                    }
                )
            )
            self.oneClickPayment = oneClickPayment
        }

        viewController.modalPresentationStyle = .overFullScreen
        oneClickIapVC = viewController
        windowService.present(modal: viewController)
        AppEvent.upsellAlertWasDisplayed.post(alert.modalSource)
    }

    private func show(_ alert: DiscourageSecureCoreAlert) {
        let discourageSecureCoreViewController = modalsFactory.discourageSecureCoreViewController(onDontShowAgain: alert.onDontShowAgain, onActivate: alert.onActivate, onCancel: alert.dismiss, onLearnMore: alert.onLearnMore)
        windowService.present(modal: discourageSecureCoreViewController)
    }

    private func show(_ alert: AppUpdateRequiredAlert) {
        alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: { [weak self] in
            self?.appSessionManager.logOut(force: true, reason: nil)
        }))

        uiAlertService.displayAlert(alert)
    }

    private func show(_: CannotAccessVpnCredentialsAlert) {
        guard appSessionManager.sessionStatus == .established else { return } // already logged out
        appSessionManager.logOut(force: true, reason: Localizable.errorSignInAgain)
    }

    private func show(_: RefreshTokenExpiredAlert) {
        appSessionManager.logOut(force: true, reason: Localizable.invalidRefreshTokenPleaseLogin)
    }

    private func show(_ alert: MaintenanceAlert) {
        switch alert.type {
        case .alert:
            showDefaultSystemAlert(alert)
        case .notification:
            showNotificationStyleAlert(message: alert.title ?? alert.message ?? "")
        }
    }

    private func show(_: ReportBugAlert) {
        settingsService.presentReportBug()
    }

    private func showDefaultSystemAlert(_ alert: SystemAlert) {
        if alert.actions.isEmpty {
            alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
        }
        uiAlertService.displayAlert(alert)
    }

    private func showNotificationStyleAlert(message: String, type: NotificationStyleAlertType = .error, accessibilityIdentifier: String? = nil) {
        uiAlertService.displayNotificationStyleAlert(message: message, type: type, accessibilityIdentifier: accessibilityIdentifier)
    }

    private func show(_: ConnectionTroubleshootingAlert) {
        let controller = TroubleshootHostingViewController()
        windowService.present(modal: controller)
    }

    private func show(_ alert: VpnServerOnMaintenanceAlert) {
        showNotificationStyleAlert(message: alert.title ?? "", type: .success)
    }

    private func show(_ alert: AnnouncementOfferAlert) {
        guard let panelMode = alert.data.panelMode() else {
            log.warning("Couldn't determine panelMode from: \(alert.data)")
            return
        }
        let announcement: AnnouncementViewController
        switch panelMode {
        case let .legacy(legacyPanel):
            announcement = AnnouncementDetailViewController(legacyPanel)
            announcement.modalPresentationStyle = .fullScreen
        case let .image(imagePanel):
            announcement = AnnouncementImageViewController(data: imagePanel, offerReference: alert.offerReference)
            announcement.modalPresentationStyle = UIDevice.current.isIpad ? .pageSheet : .overFullScreen
        }
        announcement.cancelled = { [weak self] in
            self?.windowService.dismissModal {}
        }
        announcement.urlRequested = { url in
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)

            DispatchQueue.main.async {
                AppEvent.userEngagedWithAnnouncement.post(alert.offerReference)
            }
        }
        windowService.present(modal: announcement)
    }

    private func show(_ alert: SubuserWithoutConnectionsAlert) {
        let controller = UIHostingController(rootView: NoConnectionsAvailableView(mode: alert.mode))
        windowService.present(modal: controller)
    }

    private func show(_ alert: FreeConnectionsAlert) {
        let upgradeAction: (() -> Void) = { [weak self] in
            guard let self else { return }
            windowService.dismissModal {
                if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
                    Task {
                        await self.planServiceV2.presentSubscriptionManagement(alertService: self)
                    }
                } else {
                    self.planService.presentSubscriptionManagement(alertService: self)
                }
            }
        }

        let upsellViewController = modalsFactory.freeConnectionsViewController(countries: alert.countries, upgradeAction: upgradeAction)
        windowService.present(modal: upsellViewController)
    }
}

private extension ReconnectInfo {
    func servers() -> (from: (String, UIImage), to: (String, UIImage)) {
        ((fromServer.name, fromServer.image), (toServer.name, toServer.image))
    }
}
