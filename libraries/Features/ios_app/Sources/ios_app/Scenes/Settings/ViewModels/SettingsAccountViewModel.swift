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

import CommonNetworking
import Connection
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Payments
import ProtonCoreAccountDeletion
import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import ProtonCorePasswordChange
import Sharing
import Strings
import SwiftUI
import UIKit
import VPNAppCore
import VPNShared

final class SettingsAccountViewModel {
    typealias Factory = AppSessionManagerFactory & NavigationServiceFactory
    private let factory: Factory

    @Dependency(\.coreAlertService) private var alertService
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    @Dependency(\.credentialsProvider) private var credentialsProvider
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.settingsClient) private var settingsClient
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    var pushHandler: ((UIViewController) -> Void)?
    var viewControllerFetcher: (() -> UIViewController?)?
    var reloadNeeded: (() -> Void)?

    @Dependency(\.networking) private var networking
    @Dependency(\.paymentsPlanServiceV2) private var planServiceV2
    @Dependency(\.windowService) private var windowService
    private let paymentsFlowCoordinator = PaymentsFlowCoordinator()

    init(factory: Factory) {
        self.factory = factory

        AppEvent.sessionManagerDataReloaded.subscribe(self, selector: #selector(reload))
    }

    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []

        sections.append(accountSection)
        if canShowChangePassword {
            sections.append(changePasswordSection)
        }

        sections.append(restorePurchaseSection)
        sections.append(securityKeysSection)
        sections.append(deleteAccountSection)

        return sections
    }

    private var accountSection: TableViewSection {
        let username = authKeychain.username ?? Localizable.unavailable
        let accountPlanName: String
        let allowUpgrade: Bool
        let allowPlanManagement: Bool

        if let vpnCredentials = credentialsProvider.credentials {
            accountPlanName = vpnCredentials.planTitle
            allowPlanManagement = vpnCredentials.maxTier.isPaidTier
            allowUpgrade = planServiceV2.iapStatus.isEnabled && !allowPlanManagement
        } else {
            accountPlanName = Localizable.unavailable
            allowUpgrade = false
            allowPlanManagement = false
        }

        var cells: [TableViewCellModel] = [
            .staticKeyValue(key: Localizable.username, value: username),
            .staticKeyValue(key: Localizable.subscriptionPlan, value: accountPlanName),
        ]

        if allowUpgrade {
            cells.append(.button(
                title: Localizable.upgradeSubscription,
                accessibilityIdentifier: "Upgrade Subscription",
                color: .brandColor(),
                handler: { [weak self] in self?.manageSubscriptionAction() }
            ))
        }

        if allowPlanManagement {
            cells.append(.button(
                title: Localizable.manageSubscription,
                accessibilityIdentifier: "Manage subscription",
                color: .brandColor(),
                handler: { [weak self] in self?.manageSubscriptionAction() }
            ))
        }

        return TableViewSection(title: Localizable.account.uppercased(), cells: cells)
    }

    final class ButtonWithLoadingIndicatorControllerImplementation: ButtonWithLoadingIndicatorController {
        var startLoading: () -> Void = {}
        var stopLoading: () -> Void = {}
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
        TableViewSection(title: "", cells: [
            .pushStandard(title: Localizable.changePassword, handler: { [weak self] in
                guard let self, let pushHandler else { return }
                Task { @MainActor [weak self] in
                    @SharedReader(.userSettings) var userSettings
                    guard let self, let userSettings else {
                        log.debug("No user settings found, not displaying password change menu")
                        return
                    }
                    var mode: PasswordChangeModule.PasswordChangeMode = .singlePassword
                    if userSettings.password.mode != .singlePassword {
                        mode = .loginPassword
                    }
                    if let viewController = navigationService.makePasswordChangeViewController(mode: mode) {
                        pushHandler(viewController)
                    }
                }
            }),
        ])
    }

    private var restorePurchaseSection: TableViewSection {
        TableViewSection(title: "", cells: [
            .pushStandard(title: Localizable.paymentsOptions, handler: { [weak self] in
                guard let self, let pushHandler else { return }
                pushHandler(UIHostingController(rootView: PaymentsSettingsView()))
            }),
        ])
    }

    private var securityKeysSection: TableViewSection {
        TableViewSection(title: "", cells: [
            .pushStandard(title: Localizable.securityKeys) { [weak self] in
                guard let self, let pushHandler else { return }
                Task { @MainActor [weak self] in
                    if let viewController = self?.navigationService.makeSecurityKeysViewController() {
                        pushHandler(viewController)
                    }
                }
            },
        ])
    }

    private var canShowChangePassword: Bool {
        guard let mailboxPassword = authKeychain.fetch(forContext: .mainApp)?.mailboxPassword,
              !mailboxPassword.isEmpty else {
            return false
        }
        @SharedReader(.userInfo) var userInfo
        @SharedReader(.userSettings) var userSettings
        return FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.changePassword, reloadValue: true) && userInfo != nil && userSettings != nil
    }

    private var deleteAccountSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .buttonWithLoadingIndicator(
                title: AccountDeletionService.defaultButtonName,
                accessibilityIdentifier: "Delete account",
                color: .notificationErrorColor(),
                controller: controller
            ),
            .tooltip(text: AccountDeletionService.defaultExplanationMessage),
        ]
        return TableViewSection(title: "", cells: cells)
    }

    /// Open screen with info about current plan
    private func manageSubscriptionAction() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let viewController = paymentsFlowCoordinator.makeViewController(
                request: .directSubscriptionManagement
            ) { [weak self] event in
                guard let self else { return }
                switch event {
                case .completed, .dismissed:
                    windowService.dismissModal(nil)
                case .engaged, .createAccountFirstRequested:
                    break
                }
            }
            windowService.present(modal: viewController)
        }
    }

    private func deleteAccount() {
        guard let viewController = viewControllerFetcher?() else {
            log.assertionFailure("SettingsViewModel.viewControllerFetcher must be set for account deletion flow to be presented")
            return
        }

        controller.startLoading()

        guard !isSafeToEnd else {
            proceedWithAccountDeletion(viewController: viewController)
            return
        }

        alertService.push(alert: AccountDeletionWarningAlert { [weak self] in
            self?.disconnectIfNeededThenProceed(viewController: viewController)
        } cancelHandler: { [weak self] in
            self?.controller.stopLoading()
        })
    }

    private func disconnectIfNeededThenProceed(viewController: UIViewController) {
        guard settingsClient.isActive() else {
            proceedWithAccountDeletion(viewController: viewController)
            return
        }
        Task { [weak self] in
            do {
                try await settingsClient.disconnect()
                await MainActor.run { [weak self] in
                    self?.proceedWithAccountDeletion(viewController: viewController)
                }
            } catch {
                log.error("Failed to disconnect before account deletion: \(error)", category: .connection)
                await MainActor.run { [weak self] in
                    self?.controller.stopLoading()
                }
            }
        }
    }

    private func proceedWithAccountDeletion(viewController: UIViewController) {
        let deletionService = AccountDeletionService(api: networking.apiService)
        deletionService.initiateAccountDeletionProcess(
            over: viewController,
            performAfterShowingAccountDeletionScreen: { [weak self] in
                self?.controller.stopLoading()
            }, completion: { [weak self] result in
                self?.controller.stopLoading()
                switch result {
                case .success:
                    self?.handleAccountDeletionSuccess()
                case let .failure(error):
                    self?.handleAccountDeletionFailure(error)
                }
            }
        )
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

    @objc
    private func reload() {
        reloadNeeded?()
    }

    private var isSafeToEnd: Bool {
        connectionState.isSafeToEnd
    }
}
