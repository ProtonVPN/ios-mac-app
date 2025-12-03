//
//  NavigationService.swift
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

import GSMessages
import SwiftUI
import UIKit

import ComposableArchitecture
import Dependencies

import ProtonCoreAccountRecovery
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreLoginUI
import ProtonCoreNetworking
import ProtonCorePasswordChange
import ProtonCorePushNotifications

import BugReport
import CommonNetworking
import Domain
import Ergonomics
import Home
import LegacyCommon
import Modals
import PMLogger
import Strings
import VPNAppCore
import VPNShared

// MARK: Country Service

protocol CountryService {
    func makeCountriesViewController() -> CountriesViewController
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController
}

// MARK: Profile Service

protocol ProfileService {
    func makeProfilesViewController() -> ProfilesViewController
    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController?
    func makeSelectionViewController(dataSet: SelectionDataSet, dataSelected: @escaping (Any) -> Void) -> SelectionViewController
}

// MARK: Settings Service

protocol SettingsService {
    func makeSettingsViewController() -> SettingsViewController
    func makeSettingsAccountViewController() -> SettingsAccountViewController?
    func makeExtensionsSettingsViewController() -> UIViewController
    func makeHermesSettingsViewController(viewModel: HermesSettingsViewModel) -> HermesSettingsViewController
    func makeTelemetrySettingsViewController() -> TelemetrySettingsViewController
    func makeLogSelectionViewController() -> LogSelectionViewController
    func makeLogsViewController(logSource: LogSource) -> LogsViewController
    func makeAccountRecoveryViewController() -> AccountRecoveryViewController
    func makePasswordChangeViewController(mode: PasswordChangeModule.PasswordChangeMode) -> PasswordChangeViewController?
    func presentReportBug()
}

protocol SettingsServiceFactory {
    func makeSettingsService() -> SettingsService
}

// MARK: Protocol Service

protocol ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController
}

// MARK: Connection status Service

protocol ConnectionStatusServiceFactory {
    func makeConnectionStatusService() -> ConnectionStatusService
}

extension DependencyContainer: ConnectionStatusServiceFactory {
    func makeConnectionStatusService() -> ConnectionStatusService {
        makeNavigationService()
    }
}

protocol ConnectionStatusService {
    func presentStatusViewController()
}

typealias AlertService = CoreAlertService

protocol NavigationServiceFactory {
    func makeNavigationService() -> NavigationService
}

final class NavigationService {
    typealias Factory = DependencyContainer
    private let factory: Factory

    // MARK: Storyboards

    private lazy var launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: Bundle.module)
    private lazy var countriesStoryboard = UIStoryboard(name: "Countries", bundle: Bundle.module)
    private lazy var profilesStoryboard = UIStoryboard(name: "Profiles", bundle: Bundle.module)

    // MARK: Properties

    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.windowService) private var windowService
    @Dependency(\.vpnApiClient) private var vpnApiClient
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    @Dependency(\.authKeychain) private var authKeychain
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var loginService: LoginService = {
        let loginService = factory.makeLoginService()
        loginService.delegate = self
        return loginService
    }()

    private lazy var pushNotificationService = factory.makePushNotificationService()

    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var profileManager = factory.makeProfileManager()
    @Dependency(\.announcementManager) var announcementManager
    @Dependency(\.networking) private var networking

    private lazy var onboardingService: OnboardingService = {
        let onboardingService = factory.makeOnboardingService()
        onboardingService.delegate = self
        return onboardingService
    }()

    @Dependency(\.bugReport) private var bugReportCreator

    lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()

    private var tabBarController: TabBarController?

    var vpnGateway: VpnGatewayProtocol {
        appSessionManager.vpnGateway
    }

    // MARK: Initializers

    init(_ factory: Factory) {
        self.factory = factory
    }

    @MainActor
    func launched() async {
        AppEvent.sessionManagerSessionChanged.subscribe(self, selector: #selector(sessionChanged))
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVpnManager(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        if let launchViewController = makeLaunchViewController() {
            windowService.show(viewController: launchViewController)
        }

        registerForPushNotificationsIfNeeded()

        switch await loginService.attemptSilentLogIn() {
        case .loggedIn:
            log.debug("Silent login succesfull", category: .app)
            presentMainInterface()
        case let .notLoggedIn(error):
            log.debug("Silent login failed with error: \(error)", category: .app)
            presentWelcome(initialError: nil)
        }
    }

    func presentWelcome(initialError: String?) {
        loginService.showWelcome(initialError: initialError, withOverlayViewController: nil)
        tabBarController = nil
    }

    func presentLogin(flow: LoginFlowType = .normal) {
        guard let tabBarController else { return }
        executeOnUIThread {
            self.loginService.presentLoginFlow(over: tabBarController, flow: flow)
        }
    }

    func presentSignUp() {
        guard let tabBarController else { return }
        presentSignUp(over: tabBarController)
    }

    func presentSignUp(over uiViewController: UIViewController, flow: LoginFlowType = .normal) {
        executeOnUIThread {
            self.loginService.presentSignUpFlow(over: uiViewController, flow: flow)
        }
    }

    func switchTab(index: Int) {
        guard index >= 0, index < tabBarController?.viewControllers?.count ?? 0 else {
            return
        }
        tabBarController?.selectedIndex = index
    }

    private func presentMainInterface() {
        setupTabs()
        showInitialModals()
    }

    private func registerForPushNotificationsIfNeeded() {
        if CoreFeatureFlagType.pushNotifications.enabled {
            pushNotificationService.setup()

            if CoreFeatureFlagType.accountRecovery.enabled {
                let vpnHandler = AccountRecoveryHandler()
                vpnHandler.handler = { [weak self] _ in
                    // for now, for all notification types, we take the same action
                    self?.presentAccountRecoveryViewController()
                    return .success(())
                }

                for accountRecoveryType in NotificationType.allAccountRecoveryTypes {
                    pushNotificationService.registerHandler(vpnHandler, forType: accountRecoveryType)
                }
            }
        }
    }

    func showInitialModals() {
        guard propertiesManager.showWhatsNewModal else {
            return
        }
        propertiesManager.showWhatsNewModal = false

        let variant: WhatsNewView.PlanVariant
        switch CredentialsProvider.liveValue.tier {
        case .freeTier:
            variant = .free
        case .paidTier:
            variant = .plus
        default:
            log.info("User has not explicitly a paid account, but defaulting to paid PlanVariant", category: .app)
            variant = .plus
        }

        tabBarController?.present(ModalsFactory().whatsNewViewController(variant: variant), animated: true)
    }

    @objc
    private func sessionChanged(_ notification: Notification) {
        guard appSessionManager.sessionStatus == .notEstablished else {
            return
        }
        let reasonForSessionChange = notification.object as? String
        presentWelcome(initialError: reasonForSessionChange)
    }

    @objc
    private func refreshVpnManager(_: Notification) {
        Task { @MainActor in
            await self.vpnManager.refreshManagers()
        }
    }

    private func setupTabs() {
        guard tabBarController == nil else {
            // tabBarController is present from the guest mode
            tabBarController?.selectedIndex = 0
            return
        }

        let tabBarVC = makeTabBarController()
        let tabViewControllers: [UIViewController] = [
            HomeFeatureCreator.homeViewController(),
            UINavigationController(rootViewController: makeCountriesViewController()),
            UINavigationController(rootViewController: makeProfilesViewController()),
            UINavigationController(rootViewController: makeSettingsViewController()),
        ]

        tabBarVC.setViewControllers(tabViewControllers, animated: false)
        tabBarVC.setupView()

        tabBarController = tabBarVC
        windowService.show(viewController: tabBarVC)
    }

    func makeLaunchViewController() -> LaunchViewController? {
        if let launchViewController = launchStoryboard.instantiateViewController(withIdentifier: "LaunchViewController") as? LaunchViewController {
            return launchViewController
        }
        return nil
    }

    private func makeTabBarController() -> TabBarController {
        let tabBarController = TabBarController(viewModel: TabBarViewModel(navigationService: self, sessionManager: appSessionManager))
        return tabBarController
    }
}

extension NavigationService: CountryService {
    func makeCountriesViewController() -> CountriesViewController {
        let countriesViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountriesViewController.self)) as! CountriesViewController
        countriesViewController.viewModel = CountriesViewModel(factory: factory, vpnGateway: vpnGateway, countryService: self)
        return countriesViewController
    }

    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController {
        let countryViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountryViewController.self)) as! CountryViewController
        countryViewController.viewModel = country
        return countryViewController
    }
}

extension NavigationService: ProfileService {
    func makeProfilesViewController() -> ProfilesViewController {
        let profilesViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: ProfilesViewController.self)) as! ProfilesViewController

        profilesViewController.viewModel = ProfilesViewModel(
            vpnGateway: vpnGateway,
            factory: self,
            alertService: alertService,
            connectionStatusService: self,
            planService: planService,
            profileManager: profileManager
        )
        return profilesViewController
    }

    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController? {
        guard let username = authKeychain.username else {
            return nil
        }

        guard let createProfileViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: CreateProfileViewController.self)) as? CreateProfileViewController else {
            return nil
        }

        createProfileViewController.viewModel = CreateOrEditProfileViewModel(
            username: username,
            for: profile,
            profileService: self,
            protocolSelectionService: self,
            alertService: alertService,
            appStateManager: appStateManager,
            vpnGateway: vpnGateway,
            profileManager: profileManager
        )
        return createProfileViewController
    }

    func makeSelectionViewController(dataSet: SelectionDataSet, dataSelected: @escaping (Any) -> Void) -> SelectionViewController {
        let selectionViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: SelectionViewController.self)) as! SelectionViewController
        selectionViewController.dataSet = dataSet
        selectionViewController.dataSelected = dataSelected
        return selectionViewController
    }
}

extension NavigationService: SettingsService {
    func makeSettingsViewController() -> SettingsViewController {
        let settingsViewModel = SettingsViewModel(factory: factory, protocolService: self, vpnGateway: vpnGateway)
        let settingsViewController = SettingsViewController(viewModel: settingsViewModel)
        return settingsViewController
    }

    func makeSettingsAccountViewController() -> SettingsAccountViewController? {
        SettingsAccountViewController(viewModel: SettingsAccountViewModel(factory: factory))
    }

    func makeExtensionsSettingsViewController() -> UIViewController {
        let controller = UIHostingController(rootView: WidgetSettingsView())
        controller.navigationItem.title = Localizable.widget
        return controller
    }

    func makeHermesSettingsViewController(viewModel: HermesSettingsViewModel) -> HermesSettingsViewController {
        HermesSettingsViewController(viewModel: viewModel)
    }

    func makeTelemetrySettingsViewController() -> TelemetrySettingsViewController {
        TelemetrySettingsViewController(
            preferenceChangeUsageData: { [weak self] isOn in
                self?.telemetrySettings.updateTelemetryUsageData(isOn: isOn)
            },
            preferenceChangeCrashReports: { [weak self] isOn in
                self?.telemetrySettings.updateTelemetryCrashReports(isOn: isOn)
            },
            usageStatisticsOn: { [weak self] in
                self?.telemetrySettings.telemetryUsageData ?? true
            },
            crashReportsOn: { [weak self] in
                self?.telemetrySettings.telemetryCrashReports ?? true
            },
            title: Localizable.usageStatistics
        )
    }

    func makeLogSelectionViewController() -> LogSelectionViewController {
        LogSelectionViewController(viewModel: LogSelectionViewModel(), settingsService: self)
    }

    func makeLogsViewController(logSource: LogSource) -> LogsViewController {
        @Dependency(\.logContentProvider) var logContentProvider
        return LogsViewController(viewModel: LogsViewModel(title: logSource.title, logContent: logContentProvider.getLogData(for: logSource)))
    }

    func presentReportBug() {
        let manager = factory.makeDynamicBugReportManager()
        if let viewController = bugReportCreator.createBugReportViewController(delegate: manager, colors: Colors()) {
            manager.closeBugReportHandler = { [weak self] in
                self?.windowService.dismissModal {}
            }
            manager.createAccountCallback = { [weak self] in
                self?.windowService.dismissModal {
                    self?.presentSignUp()
                }
            }

            manager.signInCallback = { [weak self] in
                self?.windowService.dismissModal {
                    self?.presentLogin(flow: .credentiallessUpsell)
                }
            }

            windowService.present(modal: viewController)
            return
        }
    }

    func makeAccountRecoveryViewController() -> AccountRecoveryViewController {
        AccountRecoveryModule.settingsViewController(networking.apiService) { [weak self] accountRecovery in
            self?.propertiesManager.userAccountRecovery = accountRecovery
        }
    }

    @MainActor
    func makePasswordChangeViewController(mode: PasswordChangeModule.PasswordChangeMode) -> PasswordChangeViewController? {
        guard let authCredentials = authKeychain.fetch() else {
            log.error("AuthCredentials not found", category: .app)
            return nil
        }
        guard let userInfo = propertiesManager.userInfo else {
            log.error("UserInfo not found", category: .app)
            return nil
        }
        guard let userSettings = propertiesManager.userSettings else {
            log.error("UserSettings not found", category: .app)
            return nil
        }
        userInfo.passwordMode = userSettings.password.mode.rawValue
        userInfo.twoFactor = userSettings._2FA.enabled.rawValue
        return PasswordChangeModule.makePasswordChangeViewController(
            mode: mode,
            apiService: networking.apiService,
            authCredential: authCredentials.toAuthCredential(),
            userInfo: userInfo
        ) { [weak self] authCredential, userInfo in
            guard let self else { return }
            processPasswordChange(authCredential: authCredential, userInfo: userInfo)
        }
    }

    @MainActor
    func makeSecurityKeysViewController() -> SecurityKeysViewController? {
        LoginUIModule.makeSecurityKeysViewController(apiService: networking.apiService, clientApp: ClientApp.vpn)
    }

    private func processPasswordChange(authCredential: AuthCredential, userInfo: UserInfo) {
        do {
            try authKeychain.store(AuthCredentials(.init(authCredential)), source: .passwordChange)
            propertiesManager.userInfo = userInfo
            windowService.popStackToRoot()
            windowService.presentMessage(Localizable.passwordChangedSuccessfully, type: .success, accessibilityIdentifier: nil)
        } catch {
            log.error("Could not update stored credentials", category: .app)
            appSessionManager.logOut(force: true, reason: "Could not update stored credentials")
        }
    }
}

extension NavigationService: ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController {
        VpnProtocolViewController(viewModel: viewModel)
    }
}

extension NavigationService: ConnectionStatusService {
    func presentStatusViewController() {
        switchTab(index: 0) // Switch to Home tab which included new connection status view.
    }
}

// MARK: Account Recovery

extension NavigationService {
    func presentAccountRecoveryViewController() {
        guard AccountRecoveryModule.feature.enabled else { return }

        let viewController = makeAccountRecoveryViewController()
        windowService.addToStack(viewController, checkForDuplicates: true)
    }
}

// MARK: Login delegate

extension NavigationService: LoginServiceDelegate {
    func userDidLogIn() {
        presentMainInterface()
    }

    @MainActor
    func userDidSignUp() {
        onboardingService.showOnboarding(overTabBarController: tabBarController)
        propertiesManager.isOnboardingInProgress = true
        // in case we're transitioning from guest -> registered improve UX by selecting first tab
        // in normal flow (start -> sign up) tabbarcontroller is nil
        switchTab(index: 0)
        Task {
            let service = await factory.makeTelemetryService()
            try await service.onboardingEvent(.onboardingStart)
        }
    }

    @MainActor
    func userDidLogInCredentialless() {
        onboardingService.showPaywall()
        propertiesManager.isOnboardingInProgress = true
        Task {
            let service = await factory.makeTelemetryService()
            try await service.onboardingEvent(.onboardingStart)
        }
    }
}

// MARK: Onboarding delegate

extension NavigationService: OnboardingServiceDelegate {
    func onboardingServiceDidFinish() {
        propertiesManager.isOnboardingInProgress = false
        presentMainInterface()
    }
}
