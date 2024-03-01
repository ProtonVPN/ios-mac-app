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
import VPNShared
import Strings

final class SettingsAccountViewModel {
    
    typealias Factory = AppSessionManagerFactory &
                        AppStateManagerFactory &
                        CoreAlertServiceFactory &
                        NetworkingFactory &
                        PlanServiceFactory &
                        PropertiesManagerFactory &
                        VpnKeychainFactory &
                        CouponViewModelFactory &
                        AuthKeychainHandleFactory

    private var factory: Factory
    
    private lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    
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
        sections.append(deleteAccountSection)
        
        return sections
    }
    
    private var accountSection: TableViewSection {
        let username = authKeychain.username ?? Localizable.unavailable
        let accountPlanName: String
        let allowUpgrade: Bool
        let allowPlanManagement: Bool
        
        if let vpnCredentials = try? vpnKeychain.fetch() {
            let accountPlan = vpnCredentials.accountPlan
            accountPlanName = vpnCredentials.accountPlan.description
            allowPlanManagement = accountPlan.paid
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
        
        if propertiesManager.featureFlags.promoCode, let credentials = try? vpnKeychain.fetchCached(), credentials.canUsePromoCode {
            cells.append(TableViewCellModel.button(title: Localizable.useCoupon, accessibilityIdentifier: "Use coupon", color: .textAccent(), handler: { [weak self] in
                self?.pushCouponViewController()
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
    
    private func pushCouponViewController() {
        pushHandler?(CouponViewController(viewModel: factory.makeCouponViewModel()))
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
