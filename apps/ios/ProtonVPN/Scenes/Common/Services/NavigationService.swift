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
import Onboarding
import Strings
import Dependencies
import Modals_iOS

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
    func makeBatteryUsageViewController() -> BatteryUsageViewController
    func makeLogsViewController(logSource: LogSource) -> LogsViewController
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
    private lazy var onboardingService: OnboardingService = {
        let onboardingService = factory.makeOnboardingService(vpnGateway: vpnGateway)
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
        _ = onboardingService // initialize colors in Onboarding module
    }

    func presentWelcome(initialError: String?) {
        loginService.showWelcome(initialError: initialError, withOverlayViewController: nil)
    }

    private func presentMainInterface() {
        setupTabs()
        showInitialModals()
    }

    func showInitialModals() {
        @Dependency(\.featureFlagProvider) var featureFlags
        let isFreeRescopeEnabled: Bool = featureFlags[\.showNewFreePlan]
        let freeRescopeReleaseDate = CoreAppConstants.WatershedEvent.freeRescopeReleaseDate
        guard let accountCreationDate = propertiesManager.userAccountCreationDate,
              accountCreationDate < freeRescopeReleaseDate,
              isFreeRescopeEnabled, // Only show the what's new modal once the free plans have been activated
              propertiesManager.showWhatsNewModal else {
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
        vpnManager.refreshManagers()
    }
    
    private func setupTabs() {
        guard let tabBarController = tabBarController else { return }
        
        tabBarController.viewModel = TabBarViewModel(navigationService: self, sessionManager: appSessionManager, appStateManager: appStateManager, vpnGateway: vpnGateway)
        
        var tabViewControllers = [UIViewController]()
        
        tabViewControllers.append(UINavigationController(rootViewController: makeCountriesViewController()))
        tabViewControllers.append(UINavigationController(rootViewController: makeMapViewController()))
        
        if let protonQCViewController = mainStoryboard.instantiateViewController(withIdentifier: "ProtonQCViewController") as? ProtonQCViewController {
            tabViewControllers.append(protonQCViewController)
        }
        
        tabViewControllers.append(UINavigationController(rootViewController: makeProfilesViewController()))
        
        if let settingsViewController = makeSettingsViewController() {
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
        mapViewController.viewModel = MapViewModel(appStateManager: appStateManager, alertService: alertService, serverStorage: ServerStorageConcrete(), vpnGateway: vpnGateway, vpnKeychain: vpnKeychain, propertiesManager: propertiesManager, connectionStatusService: self)
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

        let serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary,
                                                                 serverStorage: ServerStorageConcrete())

        createProfileViewController.viewModel = CreateOrEditProfileViewModel(username: username,
                                                                             for: profile,
                                                                             profileService: self,
                                                                             protocolSelectionService: self,
                                                                             alertService: alertService,
                                                                             vpnKeychain: vpnKeychain,
                                                                             serverManager: serverManager,
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
            usageStatisticsOn: telemetrySettings.telemetryUsageData,
            crashReportsOn: telemetrySettings.telemetryCrashReports,
            title: Localizable.usageStatistics
        )
    }
    
    func makeLogSelectionViewController() -> LogSelectionViewController {
        return LogSelectionViewController(viewModel: LogSelectionViewModel(), settingsService: self)
    }
    
    func makeBatteryUsageViewController() -> BatteryUsageViewController {
        return BatteryUsageViewController()
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

// MARK: Login delegate

extension NavigationService: LoginServiceDelegate {
    func userDidLogIn() {
        presentMainInterface()
    }

    func userDidSignUp() {
        onboardingService.showOnboarding()
    }
}

// MARK: Onboarding delegate

extension NavigationService: OnboardingServiceDelegate {
    func onboardingServiceDidFinish() {
        presentMainInterface()
    }
}
