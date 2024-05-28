//
//  SettingsAccountViewModel.swift
//  ProtonVPN - Created on 03.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import LegacyCommon
import UIKit
import ProtonCoreAccountDeletion
import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import ProtonCorePasswordChange
import VPNShared
import Strings
import CommonNetworking

final class SettingsAccountViewModel {
    
    typealias Factory = AppSessionManagerFactory &
                        AppStateManagerFactory &
                        CoreAlertServiceFactory &
                        NetworkingFactory &
                        PlanServiceFactory &
                        PropertiesManagerFactory &
                        VpnKeychainFactory &
                        AuthKeychainHandleFactory &
                        NavigationServiceFactory

    private var factory: Factory
    
    private lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var navigationService: NavigationService = factory.makeNavigationService()

    var pushHandler: ((UIViewController) -> Void)?
    var viewControllerFetcher: (() -> UIViewController?)?
    var reloadNeeded: (() -> Void)?
    
    init(factory: Factory) {
        self.factory = factory
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: appSessionManager.dataReloaded, object: nil)
    }
    
    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []
        
        sections.append(accountSection)
        if canShowChangePassword {
            sections.append(changePasswordSection)
        }
        if canShowSecurityKeys {
            sections.append(securityKeysSection)
        }
        sections.append(deleteAccountSection)
        
        return sections
    }
    
    private var accountSection: TableViewSection {
        let username = authKeychain.username ?? Localizable.unavailable
        let accountPlanName: String
        let allowUpgrade: Bool
        let allowPlanManagement: Bool
        
        if let vpnCredentials = try? vpnKeychain.fetch() {
            accountPlanName = vpnCredentials.planTitle
            allowPlanManagement = vpnCredentials.maxTier.isPaidTier
            allowUpgrade = planService.allowUpgrade && !allowPlanManagement
        } else {
            accountPlanName = Localizable.unavailable
            allowUpgrade = false
            allowPlanManagement = false
        }
        
        var cells: [TableViewCellModel] = [
            .staticKeyValue(key: Localizable.username, value: username),
            .staticKeyValue(key: Localizable.subscriptionPlan, value: accountPlanName)
        ]
        if allowUpgrade {
            cells.append(TableViewCellModel.button(title: Localizable.upgradeSubscription, accessibilityIdentifier: "Upgrade Subscription", color: .brandColor(), handler: { [weak self] in
                if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.dynamicPlan) {
                    self?.manageSubscriptionAction()
                } else {
                    self?.buySubscriptionAction()
                }
            }))
        }
        if allowPlanManagement {
            cells.append(TableViewCellModel.button(title: Localizable.manageSubscription, accessibilityIdentifier: "Manage subscription", color: .brandColor(), handler: { [weak self] in
                self?.manageSubscriptionAction()
            }))
        }

        return TableViewSection(title: Localizable.account.uppercased(), cells: cells)
    }
    
    final class ButtonWithLoadingIndicatorControllerImplementation: ButtonWithLoadingIndicatorController {
        var startLoading: () -> Void = { }
        var stopLoading: () -> Void = { }
        var handler: () -> Void
        init(handler: @escaping () -> Void) {
            self.handler = handler
        }
        func onPressed() {
            handler()
        }
    }
    
    private lazy var controller = ButtonWithLoadingIndicatorControllerImplementation { [weak self] in
        self?.deleteAccount()
    }

    private var changePasswordSection: TableViewSection {
        var cells: [TableViewCellModel] = [
            .pushStandard(title: Localizable.changePassword, handler: { [weak self] in
                guard let self, let pushHandler else { return }
                Task { @MainActor [weak self] in
                    guard let self, let userSettings = propertiesManager.userSettings else { return }
                    var mode: PasswordChangeModule.PasswordChangeMode = .singlePassword
                    if userSettings.password.mode != .singlePassword {
                        mode = .loginPassword
                    }
                    if let viewController = self.navigationService.makePasswordChangeViewController(mode: mode) {
                        pushHandler(viewController)
                    }
                }
            })
        ]
        return TableViewSection(title: "", cells: cells)
    }

    private var securityKeysSection: TableViewSection {
        var cells: [TableViewCellModel] = [
            .pushStandard(title: Localizable.securityKeys) { [weak self] in
                guard let self, let pushHandler else { return }
                Task { @MainActor [weak self] in
                    if let viewController = self?.navigationService.makeSecurityKeysViewController() {
                        pushHandler(viewController)
                    }
                }
            }
        ]
        return TableViewSection(title: "", cells: cells)
    }

    private var canShowChangePassword: Bool {
        guard let mailboxPassword = authKeychain.fetch(forContext: .mainApp)?.mailboxPassword,
              !mailboxPassword.isEmpty else {
            return false
        }
        return FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.changePassword, reloadValue: true) && propertiesManager.userInfo != nil && propertiesManager.userSettings != nil
    }

    private var canShowSecurityKeys: Bool {
        FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.fidoKeys, reloadValue: true)
    }

    private var deleteAccountSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .buttonWithLoadingIndicator(title: AccountDeletionService.defaultButtonName,
                                        accessibilityIdentifier: "Delete account",
                                        color: .notificationErrorColor(),
                                        controller: controller),
            .tooltip(text: AccountDeletionService.defaultExplanationMessage)
        ]
        return TableViewSection(title: "", cells: cells)
    }
    
    /// Open modal with new plan selection (for free/trial users and non-renewing plans)
    private func buySubscriptionAction() {
        planService.presentPlanSelection()
    }

    /// Open screen with info about current plan
    private func manageSubscriptionAction() {
        planService.presentSubscriptionManagement()
    }
    
    private func deleteAccount() {
        guard let viewController = viewControllerFetcher?() else {
            log.assertionFailure("SettingsViewModel.viewControllerFetcher must be set for account deletion flow to be presented")
            return
        }
        
        controller.startLoading()
        
        guard !appStateManager.state.isSafeToEnd else {
            proceedWithAccountDeletion(viewController: viewController)
            return
        }
        
        alertService.push(alert: AccountDeletionWarningAlert { [weak self] in
            guard let self = self else { return }
            switch self.appStateManager.state {
            case .connecting:
                self.appStateManager.cancelConnectionAttempt { [weak self] in
                    self?.proceedWithAccountDeletion(viewController: viewController)
                }
            default:
                self.appStateManager.disconnect { [weak self] in
                    self?.proceedWithAccountDeletion(viewController: viewController)
                }
            }
        } cancelHandler: { [weak self] in
            self?.controller.stopLoading()
        })
    }
    
    private func proceedWithAccountDeletion(viewController: UIViewController) {
        let deletionService = AccountDeletionService(api: factory.makeNetworking().apiService)
        deletionService.initiateAccountDeletionProcess(
            over: viewController,
            performAfterShowingAccountDeletionScreen: { [weak self] in
                self?.controller.stopLoading()
            }, completion: { [weak self] result in
                self?.controller.stopLoading()
                switch result {
                case .success: self?.handleAccountDeletionSuccess()
                case .failure(let error): self?.handleAccountDeletionFailure(error)
            }
            })
    }
    
    private func handleAccountDeletionSuccess() {
        appSessionManager.logOut(force: true, reason: nil)
    }
    
    private func handleAccountDeletionFailure(_ error: AccountDeletionError) {
        switch error {
        case .closedByUser: break
        default:
            let alert = AccountDeletionErrorAlert(message: error.userFacingMessageInAccountDeletion)
            alertService.push(alert: alert)
        }
    }
    
    @objc private func reload() {
        reloadNeeded?()
    }
}
