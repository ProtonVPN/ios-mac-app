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
import UIKit
import LegacyCommon
import SwiftUI
import BugReport
import VPNShared
import Strings
import Dependencies
import Modals_iOS
import enum Domain.VPNFeatureFlagType
import CommonNetworking

import ProtonCoreFeatureFlags
import ProtonCoreAccountRecovery
import ProtonCorePasswordChange
import ProtonCoreDataModel
import ProtonCoreLoginUI
import ProtonCoreNetworking
import ProtonCoreUIFoundations

import Home
import Home_iOS
import Settings_iOS
import ComposableArchitecture

// MARK: Country Service

protocol CountryService {
    func makeCountriesViewController() -> CountriesViewController
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController
}

// MARK: Map Service

protocol MapService {
    func makeMapViewController() -> MapViewController
}

// MARK: Profile Service

protocol ProfileService {
    func makeProfilesViewController() -> ProfilesViewController
    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController?
    func makeSelectionViewController(dataSet: SelectionDataSet, dataSelected: @escaping (Any) -> Void) -> SelectionViewController
}

// MARK: Settings Service

protocol SettingsService {
    func makeSettingsViewController() -> SettingsViewController?
    func makeSettingsAccountViewController() -> SettingsAccountViewController?
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController
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
        return makeNavigationService()
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
    private lazy var launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
    private lazy var mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    private lazy var commonStoryboard = UIStoryboard(name: "Common", bundle: nil)
    private lazy var countriesStoryboard = UIStoryboard(name: "Countries", bundle: nil)
    private lazy var profilesStoryboard = UIStoryboard(name: "Profiles", bundle: nil)
    
    // MARK: Properties
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var loginService: LoginService = {
        let loginService = factory.makeLoginService()
        loginService.delegate = self
        return loginService
    }()
    private lazy var networking: Networking = factory.makeNetworking()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var profileManager = factory.makeProfileManager()
    private lazy var sessionService = factory.makeSessionService()

    private lazy var onboardingService: OnboardingService = {
        let onboardingService = factory.makeOnboardingService()
        onboardingService.delegate = self
        return onboardingService
    }()

    private lazy var bugReportCreator: BugReportCreator = factory.makeBugReportCreator()

    private lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()

    private lazy var connectionBarViewController = { 
        return makeConnectionBarViewController()
    }()

    private lazy var tabBarController = {
        return makeTabBarController()
    }()
    
    var vpnGateway: VpnGatewayProtocol {
        return appSessionManager.vpnGateway
    }
    
    // MARK: Initializers
    init(_ factory: Factory) {
        self.factory = factory
    }
    
    func launched() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged(_:)),
                                               name: appSessionManager.sessionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVpnManager(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        if let launchViewController = makeLaunchViewController() {
            windowService.show(viewController: launchViewController)
        }
        
        loginService.attemptSilentLogIn { [weak self] result in
            switch result {
            case .loggedIn:
                self?.presentMainInterface()
            case .notLoggedIn:
                self?.presentWelcome(initialError: nil)
            }
        }
    }

    func presentWelcome(initialError: String?) {
        loginService.showWelcome(initialError: initialError, withOverlayViewController: nil)
    }

    private func presentMainInterface() {
        setupTabs()
        showInitialModals()
    }

    func showInitialModals() {
        guard propertiesManager.showWhatsNewModal else {
            return
        }
        propertiesManager.showWhatsNewModal = false

        tabBarController?.present(ModalsFactory().whatsNewViewController(), animated: true)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        guard appSessionManager.sessionStatus == .notEstablished else {
            return
        }
        let reasonForSessionChange = notification.object as? String
        presentWelcome(initialError: reasonForSessionChange)
    }
    
    @objc private func refreshVpnManager(_ notification: Notification) {
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.asyncVPNManager) {
            Task { @MainActor in
                await self.vpnManager.refreshManagers()
            }
        } else {
            vpnManager.refreshManagers()
        }
    }
    
    private func setupTabs() {
        guard let tabBarController = tabBarController else { return }
        
        tabBarController.viewModel = TabBarViewModel(navigationService: self, sessionManager: appSessionManager, appStateManager: appStateManager, vpnGateway: vpnGateway)
        
        var tabViewControllers = [UIViewController]()
        
        let isRedesign = FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS)

        if isRedesign {
            let hostingController = UIHostingController(rootView: HomeView())
            hostingController.tabBarItem = UITabBarItem(title: Localizable.homeTab,
                                                        image: IconProvider.houseFilled,
                                                        tag: 0)
            tabViewControllers.append(hostingController)
        }

        tabViewControllers.append(UINavigationController(rootViewController: makeCountriesViewController()))
        
        if !isRedesign {
            tabViewControllers.append(UINavigationController(rootViewController: makeMapViewController()))

            if let protonQCViewController = mainStoryboard.instantiateViewController(withIdentifier: "ProtonQCViewController") as? ProtonQCViewController {
                tabViewControllers.append(protonQCViewController)
            }
        }
        
        tabViewControllers.append(UINavigationController(rootViewController: makeProfilesViewController()))
        
        if isRedesign {
            let hostingController = UIHostingController(rootView: SettingsView())
            hostingController.tabBarItem = UITabBarItem(title: Localizable.settingsTab,
                                                        image: IconProvider.cogWheel,
                                                        tag: 0)
            tabViewControllers.append(hostingController)
        } else if let settingsViewController = makeSettingsViewController() {
            tabViewControllers.append(UINavigationController(rootViewController: settingsViewController))
        }

        tabBarController.setViewControllers(tabViewControllers, animated: false)
        tabBarController.setupView()
        
        windowService.show(viewController: tabBarController)
    }
    
    func makeLaunchViewController() -> LaunchViewController? {
        if let launchViewController = launchStoryboard.instantiateViewController(withIdentifier: "LaunchViewController") as? LaunchViewController {
            return launchViewController
        }
        return nil
    }
    
    private func makeTabBarController() -> TabBarController? {
        guard let tabBarController = mainStoryboard.instantiateViewController(withIdentifier: "TabBarController") as? TabBarController else { return nil }
        tabBarController.viewModel = TabBarViewModel(navigationService: self, sessionManager: appSessionManager, appStateManager: appStateManager, vpnGateway: vpnGateway)
        
        return tabBarController
    }
}

extension NavigationService: CountryService {
    func makeCountriesViewController() -> CountriesViewController {
        let countriesViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountriesViewController.self)) as! CountriesViewController
        countriesViewController.viewModel = CountriesViewModel(factory: factory, vpnGateway: vpnGateway, countryService: self)
        countriesViewController.sessionService = sessionService
        countriesViewController.connectionBarViewController = makeConnectionBarViewController()
        
        return countriesViewController
    }
    
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController {
        let countryViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountryViewController.self)) as! CountryViewController
        countryViewController.viewModel = country
        countryViewController.connectionBarViewController = makeConnectionBarViewController()
        return countryViewController
    }
}

extension NavigationService: MapService {
    func makeMapViewController() -> MapViewController {
        let mapViewController = mainStoryboard.instantiateViewController(withIdentifier: String(describing: MapViewController.self)) as! MapViewController
        mapViewController.viewModel = MapViewModel(appStateManager: appStateManager, alertService: alertService, vpnGateway: vpnGateway, vpnKeychain: vpnKeychain, propertiesManager: propertiesManager, connectionStatusService: self)
        mapViewController.connectionBarViewController = makeConnectionBarViewController()
        return mapViewController
    }
}

extension NavigationService: ProfileService {
    func makeProfilesViewController() -> ProfilesViewController {
        let profilesViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: ProfilesViewController.self)) as! ProfilesViewController
        profilesViewController.viewModel = ProfilesViewModel(vpnGateway: vpnGateway, factory: self, alertService: alertService, propertiesManager: propertiesManager, connectionStatusService: self, netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(), natTypePropertyProvider: factory.makeNATTypePropertyProvider(), safeModePropertyProvider: factory.makeSafeModePropertyProvider(), planService: planService, profileManager: profileManager)
        profilesViewController.connectionBarViewController = makeConnectionBarViewController()
        return profilesViewController
    }
    
    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController? {
        guard let username = authKeychain.username else {
            return nil
        }

        guard let createProfileViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: CreateProfileViewController.self)) as? CreateProfileViewController else {
            return nil
        }

        createProfileViewController.viewModel = CreateOrEditProfileViewModel(username: username,
                                                                             for: profile,
                                                                             profileService: self,
                                                                             protocolSelectionService: self,
                                                                             alertService: alertService,
                                                                             vpnKeychain: vpnKeychain,
                                                                             appStateManager: appStateManager,
                                                                             vpnGateway: vpnGateway,
                                                                             profileManager: profileManager,
                                                                             propertiesManager: propertiesManager)
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
    
    func makeSettingsViewController() -> SettingsViewController? {
        if let settingsViewController = mainStoryboard.instantiateViewController(withIdentifier: String(describing: SettingsViewController.self)) as? SettingsViewController {
            settingsViewController.viewModel = SettingsViewModel(factory: factory, protocolService: self, vpnGateway: vpnGateway)
            settingsViewController.connectionBarViewController = makeConnectionBarViewController()
            return settingsViewController
        }
        
        return nil
    }
    
    func makeSettingsAccountViewController() -> SettingsAccountViewController? {
        guard let connectionBar = makeConnectionBarViewController() else { return nil }
        return SettingsAccountViewController(viewModel: SettingsAccountViewModel(factory: factory), connectionBar: connectionBar)
    }
    
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController {
        return WidgetSettingsViewController(viewModel: WidgetSettingsViewModel())
    }

    func makeTelemetrySettingsViewController() -> TelemetrySettingsViewController {
        return TelemetrySettingsViewController(
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
        return LogSelectionViewController(viewModel: LogSelectionViewModel(), settingsService: self)
    }
    
    func makeLogsViewController(logSource: LogSource) -> LogsViewController {
        return LogsViewController(viewModel: LogsViewModel(title: logSource.title, logContent: factory.makeLogContentProvider().getLogData(for: logSource)))
    }
    
    func presentReportBug() {
        let manager = factory.makeDynamicBugReportManager()
        if let viewController = bugReportCreator.createBugReportViewController(delegate: manager, colors: Colors()) {
            manager.closeBugReportHandler = {
                self.windowService.dismissModal { }
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
        guard let authCredentials = authKeychain.fetch(forContext: .mainApp) else {
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
        userInfo.twoFactor = userSettings.twoFactor.type.rawValue
        return PasswordChangeModule.makePasswordChangeViewController(
            mode: mode,
            apiService: networking.apiService,
            authCredential: authCredentials.toAuthCredential(),
            userInfo: userInfo
        ) { [weak self] authCredential, userInfo in
            guard let self else { return }
            self.processPasswordChange(authCredential: authCredential, userInfo: userInfo)
        }
    }

    @MainActor
    func makeSecurityKeysViewController() -> SecurityKeysViewController? {
        LoginUIModule.makeSecurityKeysViewController(apiService: networking.apiService, clientApp: ClientApp.vpn)
    }

    private func processPasswordChange(authCredential: AuthCredential, userInfo: UserInfo) {
        do {
            try authKeychain.store(AuthCredentials(.init(authCredential)))
            self.propertiesManager.userInfo = userInfo
            self.windowService.popStackToRoot()
            self.windowService.present(message: Localizable.passwordChangedSuccessfully, type: .success, accessibilityIdentifier: nil)
        } catch {
            log.error("Could not update stored credentials", category: .app)
            appSessionManager.logOut(force: true, reason: "Could not update stored credentials")
        }
    }
}

extension NavigationService: ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController {
        return VpnProtocolViewController(viewModel: viewModel)
    }
}

extension NavigationService: ConnectionStatusService {
    func makeConnectionBarViewController() -> ConnectionBarViewController? {
        
        if let connectionBarViewController =
            self.commonStoryboard.instantiateViewController(withIdentifier:
                String(describing: ConnectionBarViewController.self)) as? ConnectionBarViewController {
            
            connectionBarViewController.viewModel = ConnectionBarViewModel(appStateManager: appStateManager)
            connectionBarViewController.connectionStatusService = self
            return connectionBarViewController
        }
        
        return nil
    }
    
    func makeStatusViewController() -> StatusViewController? {
        if let statusViewController =
            self.commonStoryboard.instantiateViewController(withIdentifier:
                String(describing: StatusViewController.self)) as? StatusViewController {
            statusViewController.viewModel = StatusViewModel(factory: factory)
            return statusViewController
        }
        return nil
    }
    
    func presentStatusViewController() {
        guard let viewController = makeStatusViewController() else {
            return
        }
        self.windowService.addToStack(viewController, checkForDuplicates: true)
    }    
}

// MARK: Account Recovery
extension NavigationService {
    func presentAccountRecoveryViewController() {
        guard FeatureFlagsRepository.shared.isEnabled(AccountRecoveryModule.feature) else { return }

        let viewController = makeAccountRecoveryViewController()
        self.windowService.addToStack(viewController, checkForDuplicates: true)
    }
}

// MARK: Login delegate

extension NavigationService: LoginServiceDelegate {
    func userDidLogIn() {
        presentMainInterface()
    }

    @MainActor
    func userDidSignUp() {
        onboardingService.showOnboarding()
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
