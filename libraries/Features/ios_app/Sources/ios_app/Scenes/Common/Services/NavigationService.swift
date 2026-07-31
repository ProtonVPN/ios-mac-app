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

import BugReport
import Combine
import CommonNetworking
import ComposableArchitecture
import Countries
import Dependencies
import Domain
import Ergonomics
import GSMessages
import Home
import LegacyCommon
import Mobile
import Modals
import PMLogger
import ProtonCoreAccountRecovery
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreLoginUI
import ProtonCoreNetworking
import ProtonCorePasswordChange
import ProtonCorePushNotifications
import ProtonCoreServices
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Telemetry
import UIKit
import VPNAppCore
import VPNShared

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
    func makeLogSelectionViewController() -> LogSelectionViewController
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
    func presentHome()
}

protocol NavigationServiceFactory {
    func makeNavigationService() -> NavigationService
}

final class NavigationService {
    typealias Factory = DependencyContainer
    private let factory: Factory

    // MARK: Storyboards

    private lazy var profilesStoryboard = UIStoryboard(name: "Profiles", bundle: Bundle.module)

    // MARK: Properties

    @Dependency(\.windowService) private var windowService
    @Dependency(\.vpnApiClient) private var vpnApiClient
    @Dependency(\.credentialsProvider) private var credentialsProvider
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    @SharedReader(.sessionStatus) private var sessionStatus: SessionStatus
    @SharedReader(.sessionLogoutReason) private var sessionLogoutReason: String?
    private var cancellables = Set<AnyCancellable>()
    @Dependency(\.authKeychain) private var authKeychain
    private lazy var loginService: LoginService = {
        let loginService = factory.makeLoginService()
        loginService.delegate = self
        return loginService
    }()

    private lazy var pushNotificationService = factory.makePushNotificationService()

    @Dependency(\.announcementManager) var announcementManager
    @Dependency(\.networking) private var networking

    private lazy var onboardingService: OnboardingService = {
        let onboardingService = factory.makeOnboardingService()
        onboardingService.delegate = self
        return onboardingService
    }()

    @Dependency(\.bugReport) private var bugReportCreator

    var tabBarController = TabBarController()

    /// The app's main TCA store.
    private var appStore: StoreOf<TabularFeature>?
    /// Bridges the sheet and the tab bar to the store. Held here because UIKit keeps delegates weakly.
    private var shellObserver: AppShellObserver?
    /// How much of the backdrop the sheet covers right now, read by the backdrop view and written by the
    /// observer. Rebuilt with the rest of the shell, so a new login starts uncovered.
    private var sheetOverlap = SheetOverlap()

    // MARK: Initializers

    init(_ factory: Factory) {
        self.factory = factory
    }

    @MainActor
    func showLaunchScreen() {
        windowService.show(viewController: makeLaunchViewController())
    }

    @MainActor
    func launched() async {
        $sessionStatus.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.sessionChanged(status) }
            .store(in: &cancellables)

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
        // Release the shell with the login it belonged to. The store keeps the feature tree and its
        // long-running observations (connection state, recents, shared properties) alive for as long as
        // it exists, and none of that should keep running for a user who signed out.
        appStore = nil
        shellObserver = nil
        // Release the old tab bar and start fresh. Merely nilling `viewControllers` on the reused,
        // already-presented instance is unreliable — UIKit reads it back as a non-nil/empty array, so
        // `setupTabs`' `== nil` guard would skip the rebuild and re-show this stale instance (still holding
        // the previous session's Settings nav with the tab bar hidden). A brand-new instance reports
        // `viewControllers == nil` reliably, so the next login rebuilds the tabs with post-login data.
        tabBarController = TabBarController()
    }

    func presentLogin(flow: LoginFlowType = .normal) {
        executeOnUIThread { [tabBarController] in
            self.loginService.presentLoginFlow(over: tabBarController, flow: flow)
        }
    }

    func presentSignUp() {
        presentSignUp(over: tabBarController)
    }

    func presentSignUp(over uiViewController: UIViewController, flow: LoginFlowType = .normal) {
        executeOnUIThread {
            self.loginService.presentSignUpFlow(over: uiViewController, flow: flow)
        }
    }

    @MainActor
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
        @Shared(.showWhatsNewModal) var showWhatsNewModal
        guard showWhatsNewModal else {
            return
        }
        $showWhatsNewModal.withLock { $0 = false }

        let variant: WhatsNewView.PlanVariant
        switch credentialsProvider.tier {
        case .free:
            variant = .free
        case .paid:
            variant = .plus
        default:
            log.info("User has not explicitly a paid account, but defaulting to paid PlanVariant", category: .app)
            variant = .plus
        }

        tabBarController.present(ModalsFactory().whatsNewViewController(variant: variant), animated: true)
    }

    private func sessionChanged(_ status: SessionStatus) {
        guard status == .notEstablished else {
            return
        }
        presentWelcome(initialError: sessionLogoutReason)
    }

    /// Builds the main view. The globe backdrop becomes the window's root, with tabs presented over it in a sheet the
    /// user can raise and lower.
    @MainActor
    private func setupTabs() {
        guard tabBarController.viewControllers?.isEmpty ?? true else {
            appStore?.send(.tabSelected(.home))
            return
        }

        // The coverage channel is per-shell like the store and observer below, so the last login's final sheet position
        // cannot show through the first frames of this one.
        sheetOverlap = SheetOverlap()

        let store = StoreOf<TabularFeature>(initialState: .init()) {
            log.info("Creating TabularFeature", category: .app)
            return TabularFeature()
        } withDependencies: {
            $0.openCredentiallessSignUp = { [weak self] in
                guard let self else { return }
                presentSignUp(over: tabBarController, flow: .credentiallessUpsell)
            }
        }
        appStore = store

        let backdrop = UIHostingController(rootView: TabularBackdropView(store: store, overlap: sheetOverlap))
        windowService.show(viewController: backdrop)

        // One page per shell tab, in `Tab.allCases` order: the observer translates the tab bar's
        // selection index through that same list, so the enum is the only place the order is written.
        tabBarController.setViewControllers(TabularFeature.Tab.allCases.map { tab -> UIViewController in
            switch tab {
            case .home: makeHomeViewController(store: store.scope(state: \.home, action: \.home))
            case .countries: makeCountriesViewController()
            case .profiles: UINavigationController(rootViewController: makeProfilesViewController())
            case .settings: UINavigationController(rootViewController: makeSettingsViewController())
            }
        }, animated: false)
        tabBarController.setupView()

        // Those should be called once
        store.send(.commands(.onStart))
        store.send(.home(.onStart))
        store.send(.home(.sharedProperties(.listen)))
        store.send(.map(.observeConnectionState))

        presentTabSheet(over: backdrop, store: store)
    }

    @MainActor
    private func presentTabSheet(over backdrop: UIViewController, store: StoreOf<TabularFeature>) {
        let observer = AppShellObserver(store: store, overlap: sheetOverlap)
        shellObserver = observer
        tabBarController.delegate = observer
        tabBarController.isModalInPresentation = true // the tabs are the app, so the sheet never dismisses

        if let sheet = tabBarController.sheetPresentationController {
            sheet.delegate = observer
            // One fixed ladder for every tab; only the selection moves, applied by the observer.
            sheet.detents = TabularFeature.Detent.allCases.map(\.sheetDetent)
            sheet.largestUndimmedDetentIdentifier = TabularFeature.Detent.allCases.last?.identifier
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersGrabberVisible = true
            observer.observeShellState(sheet: sheet, tabs: tabBarController)
        }

        observer.trackSheetHeight(of: tabBarController)
        backdrop.present(tabBarController, animated: false)
    }

    private func makeHomeViewController(store: StoreOf<HomeFeature>) -> UIViewController {
        let hostingController = UIHostingController(rootView: HomeView(store: store))
        hostingController.tabBarItem = UITabBarItem(title: Localizable.homeTab, image: IconProvider.houseFilled, tag: 0)
        hostingController.tabBarItem.accessibilityIdentifier = "Home"
        return hostingController
    }

    func makeLaunchViewController() -> LaunchViewController {
        LaunchViewController()
    }
}

extension NavigationService {
    func makeCountriesViewController() -> UIViewController {
        let countriesState = CountriesMainFeature.State.loading
        let countriesStore = StoreOf<CountriesMainFeature>(initialState: countriesState) {
            CountriesMainFeature()
        } withDependencies: {
            $0.openCredentiallessSignUp = { [weak self] in
                guard let vc = self?.windowService.topmostPresentedViewController() else { return }
                self?.presentSignUp(over: vc, flow: .credentiallessUpsell)
            }
            $0.switchToPrimaryTab = {
                // Connecting no longer changes tabs: the backdrop's status chrome and camera flight are
                // visible behind every page, so there is nothing on Home the user has to be taken to.
            }
        }
        let countriesView = CountriesMainView(store: countriesStore)
        let hostingController = UIHostingController(rootView: countriesView)
        hostingController.tabBarItem = UITabBarItem(title: Localizable.countries, image: IconProvider.earth, tag: 1)
        hostingController.tabBarItem.accessibilityIdentifier = "Countries"

        // Ensure content extends under tab bar
        hostingController.edgesForExtendedLayout = [.bottom]
        hostingController.extendedLayoutIncludesOpaqueBars = true

        return hostingController
    }
}

extension NavigationService: ProfileService {
    func makeProfilesViewController() -> ProfilesViewController {
        let profilesViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: ProfilesViewController.self)) as! ProfilesViewController

        profilesViewController.viewModel = ProfilesViewModel(profileService: self, connectionStatusService: self)
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
            protocolSelectionService: self
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
        let settingsViewModel = SettingsViewModel(factory: factory, protocolService: self)
        return SettingsViewController(viewModel: settingsViewModel)
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

    func makeLogSelectionViewController() -> LogSelectionViewController {
        LogSelectionViewController(
            store: Store(
                initialState: LogSelectionFeature.State(),
                reducer: { LogSelectionFeature() }
            )
        )
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
        @Shared(.userAccountRecovery) var userAccountRecovery
        return AccountRecoveryModule.settingsViewController(networking.apiService) { accountRecovery in
            $userAccountRecovery.withLock { $0 = accountRecovery }
        }
    }

    @MainActor
    func makePasswordChangeViewController(mode: PasswordChangeModule.PasswordChangeMode) -> PasswordChangeViewController? {
        guard let authCredentials = authKeychain.fetch() else {
            log.error("AuthCredentials not found", category: .app)
            return nil
        }
        @SharedReader(.userInfo) var userInfo
        guard let userInfo else {
            log.error("UserInfo not found", category: .app)
            return nil
        }
        @SharedReader(.userSettings) var userSettings
        guard let userSettings else {
            log.error("UserSettings not found", category: .app)
            return nil
        }
        userInfo.apply(userSettings)
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
            @Shared(.userInfo) var sharedUserInfo
            $sharedUserInfo.withLock { $0 = userInfo }
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
    func presentHome() {
        // Through the store, never the tab bar directly: the shell is the authority on the selected
        // tab, and a raw selectedIndex write would be snapped back by the observation on the next
        // state change.
        Task { @MainActor [weak self] in
            self?.appStore?.send(.tabSelected(.home))
        }
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
    @MainActor
    func userDidLogIn() {
        presentMainInterface()
    }

    @MainActor
    func userDidSignUp() {
        onboardingService.showOnboarding(overTabBarController: tabBarController)
        TelemetryOnboardingReporter.isOnboardingInProgress = true
        // in case we're transitioning from guest -> registered improve UX by selecting first tab
        // in normal flow (start -> sign up) tabbarcontroller is nil
        presentHome()
        @Dependency(\.telemetryService) var service
        Task {
            try await service.onboardingEvent(.onboardingStart)
        }
    }

    @MainActor
    func userDidLogInCredentialless() {
        onboardingService.showPaywall()
        TelemetryOnboardingReporter.isOnboardingInProgress = true
        @Dependency(\.telemetryService) var service
        Task {
            try await service.onboardingEvent(.onboardingStart)
        }
    }
}

// MARK: Onboarding delegate

extension NavigationService: OnboardingServiceDelegate {
    @MainActor
    func onboardingServiceDidFinish() {
        TelemetryOnboardingReporter.isOnboardingInProgress = false
        presentMainInterface()
    }
}
