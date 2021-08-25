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
import vpncore

// MARK: Plan Service

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        return makeNavigationService()
    }
}

protocol PlanService {
    func makePurchaseCompleteViewController(plan: AccountPlan) -> PurchaseCompleteViewController?
    func presentPlanSelection(viewModel: PlanSelectionViewModel)
    func presentPlanSelection()
    func presentSubscriptionManagement(plan: AccountPlan)
}

// MARK: Country Service

protocol CountryService {
    func makeCountriesViewController() -> CountriesViewController
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController
}

// MARK: Announcements Service

protocol AnnouncementsServiceFactory {
    func makeAnnouncementsService() -> AnnouncementsService
}

extension DependencyContainer: AnnouncementsServiceFactory {
    func makeAnnouncementsService() -> AnnouncementsService {
        return makeNavigationService()
    }
}
protocol AnnouncementsService {
    func makeAnnouncementsViewController() -> AnnouncementsViewController
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
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController
    func makeLogSelectionViewController() -> LogSelectionViewController
    func makeBatteryUsageViewController() -> BatteryUsageViewController
    func makeLogsViewController(viewModel: LogsViewModel) -> LogsViewController
    func makeCustomServerViewController() -> CustomServersViewController
    func presentReportBug()
}

protocol SettingsServiceFactory {
    func makeSettingsService() -> SettingsService
}

// MARK: Protocol Service

protocol ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController
}

// MARK: Netshield Service

protocol NetshieldService {
    func makeNetshieldSelectionViewController(selectedType: NetShieldType, approve: @escaping NetshieldSelectionViewModel.ApproveCallback, onChange: @escaping NetshieldSelectionViewModel.TypeChangeCallback) -> NetshieldSelectionViewController
}

protocol NetshieldServiceFactory {
    func makeNetshieldService() -> NetshieldService
}

extension DependencyContainer: NetshieldServiceFactory {
    func makeNetshieldService() -> NetshieldService {
        return makeNavigationService()
    }
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
    
    typealias Factory =       
        PropertiesManagerFactory & WindowServiceFactory & VpnKeychainFactory & VpnApiServiceFactory & AppStateManagerFactory & AppSessionManagerFactory & TrialCheckerFactory & CoreAlertServiceFactory & ReportBugViewModelFactory & PaymentsApiServiceFactory & VpnManagerFactory & UIAlertServiceFactory & PlanSelectionViewModelFactory & ServicePlanDataServiceFactory & SubscriptionInfoViewModelFactory & ServicePlanDataStorageFactory & StoreKitManagerFactory & PlanServiceFactory & VpnGatewayFactory & ProfileManagerFactory & NetshieldServiceFactory & AnnouncementsViewModelFactory & AnnouncementManagerFactory & ConnectionStatusServiceFactory & NetShieldPropertyProviderFactory & VpnStateConfigurationFactory & LoginServiceFactory & NetworkingFactory
    private let factory: Factory
    
    // MARK: Storyboards
    private lazy var launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
    private lazy var mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    private lazy var commonStoryboard = UIStoryboard(name: "Common", bundle: nil)
    private lazy var countriesStoryboard = UIStoryboard(name: "Countries", bundle: nil)
    private lazy var subscriptionsStoryboard = UIStoryboard(name: "Subscriptions", bundle: nil)
    private lazy var profilesStoryboard = UIStoryboard(name: "Profiles", bundle: nil)
    
    // MARK: Properties
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var paymentsApiService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var servicePlanDataService: ServicePlanDataService = factory.makeServicePlanDataService()
    private lazy var servicePlanDataStorage: ServicePlanDataStorage = factory.makeServicePlanDataStorage()
    private lazy var storeKitManager: StoreKitManager = factory.makeStoreKitManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var networking: Networking = factory.makeNetworking()
    
    private var trialChecker: TrialChecker?
    
    private lazy var profileManager = {
        return ProfileManager.shared
    }()
    private lazy var connectionBarViewController = { 
        return makeConnectionBarViewController()
    }()

    private lazy var tabBarController = {
        return makeTabBarController()
    }()
    
    var vpnGateway: VpnGatewayProtocol? {
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
                self?.presentWelcome()
            }
        }
    }

    func presentWelcome() {
        loginService.showWelcome()
    }

    func presentMainInterface() {
        setupTabs()
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if appSessionManager.vpnGateway != nil {
            trialChecker = factory.makeTrialChecker()
        } else {
            trialChecker = nil
        }
        
        if appSessionManager.sessionStatus == .notEstablished {
            presentWelcome()
            return
        }
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

// MARK: - PlanService

extension NavigationService: PlanService {
        
    func makePurchaseCompleteViewController(plan: AccountPlan) -> PurchaseCompleteViewController? {
        if let signUpCompleteViewController = subscriptionsStoryboard.instantiateViewController(withIdentifier: "SignUpCompleteViewController") as? PurchaseCompleteViewController {
            signUpCompleteViewController.navigationService = self
            signUpCompleteViewController.plan = plan
            return signUpCompleteViewController
        }
        return nil
    }
    
    func presentPlanSelection(viewModel: PlanSelectionViewModel) {
        let planSelectionViewController = PlanSelectionViewController(viewModel)
        let nc = UINavigationController(rootViewController: planSelectionViewController)
        
        nc.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        nc.navigationBar.shadowImage = UIImage()
        nc.navigationBar.isTranslucent = true
        nc.modalPresentationStyle = .fullScreen
        
        self.windowService.replace(with: nc)
    }
    
    /// Shorthand version for presenting plen selection view controller.
    /// Additionally, this checks if user can use In App Purchase and if not, presents alert.
    func presentPlanSelection() {
        guard servicePlanDataService.isIAPUpgradePlanAvailable else {
            alertService.push(alert: UpgradeUnavailableAlert())
            return
        }

        let viewModel = factory.makePlanSelectionWithPurchaseViewModel()
        viewModel.cancelled = {
            self.windowService.dismissModal()
        }
        presentPlanSelection(viewModel: viewModel)
    }
    
    func presentSubscriptionManagement(viewModel: SubscriptionInfoViewModel) {
        let controller = SubscriptionInfoController(viewModel: viewModel, alertService: self.alertService)
        let nc = UINavigationController(rootViewController: controller)
        
        nc.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        nc.navigationBar.shadowImage = UIImage()
        nc.navigationBar.isTranslucent = true
        nc.modalPresentationStyle = .fullScreen
        
        self.windowService.replace(with: nc)
    }
    
    func presentSubscriptionManagement(plan: AccountPlan) {
        let viewModel = factory.makeSubscriptionInfoViewModel(plan: plan)
        viewModel.cancelled = {
            self.windowService.dismissModal()
        }
        presentSubscriptionManagement(viewModel: viewModel)
    }
    
}

extension NavigationService: TrialService {
    func presentTrialWelcomeViewController(expiration: Date) {
        // Prevents issues with other modals being dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [windowService, vpnKeychain] in
            let viewModel = TrialWelcomeViewModel(expiration: expiration, planService: self, planChecker: PlanUpgradeChecker(vpnKeychain: vpnKeychain))
            let trialWelcomeViewController = TrialWelcomeViewController(viewModel, windowService: windowService)
            windowService.present(modal: trialWelcomeViewController)
        }
    }
    
    func presentTrialExpiredViewController() {
        // FUTUREFIX: should be a custom VC
        
        let alert = TrialExpiredAlert(confirmHandler: { [weak self] in
            self?.presentPlanSelection()
        }, cancelHandler: {}, planChecker: PlanUpgradeChecker(vpnKeychain: vpnKeychain))
        alertService.push(alert: alert)
    }
}

extension NavigationService: CountryService {
    func makeCountriesViewController() -> CountriesViewController {
        let countriesViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountriesViewController.self)) as! CountriesViewController
        countriesViewController.viewModel = CountriesViewModel(factory: factory, vpnGateway: vpnGateway, countryService: self)
        countriesViewController.connectionBarViewController = makeConnectionBarViewController()
        countriesViewController.planService = self
        
        return countriesViewController
    }
    
    func makeCountryViewController(country: CountryItemViewModel) -> CountryViewController {
        let countryViewController = countriesStoryboard.instantiateViewController(withIdentifier: String(describing: CountryViewController.self)) as! CountryViewController
        countryViewController.viewModel = country
        countryViewController.connectionBarViewController = makeConnectionBarViewController()
        return countryViewController
    }
}

extension NavigationService: AnnouncementsService {
    func makeAnnouncementsViewController() -> AnnouncementsViewController {
        let controller = AnnouncementsViewController(factory.makeAnnouncementsViewModel())
        return controller
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
        profilesViewController.viewModel = ProfilesViewModel(vpnGateway: vpnGateway, factory: self, alertService: alertService, planService: self, propertiesManager: propertiesManager, connectionStatusService: self, netShieldPropertyProvider: factory.makeNetShieldPropertyProvider())
        profilesViewController.connectionBarViewController = makeConnectionBarViewController()
        return profilesViewController
    }
    
    func makeCreateProfileViewController(for profile: Profile?) -> CreateProfileViewController? {
        if let createProfileViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: CreateProfileViewController.self)) as? CreateProfileViewController {
            createProfileViewController.viewModel = CreateOrEditProfileViewModel(for: profile, profileService: self, protocolSelectionService: self, alertService: alertService, vpnKeychain: vpnKeychain, serverManager: ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete()), appStateManager: appStateManager, vpnGateway: vpnGateway!)
            return createProfileViewController
        }
        return nil
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
            settingsViewController.viewModel = SettingsViewModel(appStateManager: appStateManager, appSessionManager: appSessionManager, vpnGateway: vpnGateway, alertService: alertService, planService: self, settingsService: self, protocolService: self, vpnKeychain: vpnKeychain, netshieldService: self, connectionStatusService: self, netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(), vpnManager: vpnManager, vpnStateConfiguration: vpnStateConfiguration)
            settingsViewController.connectionBarViewController = makeConnectionBarViewController()
            return settingsViewController
        }
        
        return nil
    }
    
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController {
        return WidgetSettingsViewController(viewModel: WidgetSettingsViewModel())
    }
    
    func makeLogSelectionViewController() -> LogSelectionViewController {
        return LogSelectionViewController(viewModel: LogSelectionViewModel(logFileProvider: DefaultLogFilesProvider(vpnManager: vpnManager)), settingsService: self)
    }
    
    func makeBatteryUsageViewController() -> BatteryUsageViewController {
        return BatteryUsageViewController()
    }
    
    func makeLogsViewController(viewModel: LogsViewModel) -> LogsViewController {
        return LogsViewController(viewModel: viewModel)
    }

    func makeCustomServerViewController() -> CustomServersViewController {
        return CustomServersViewController(viewModel: CustomServersViewModel(factory: factory, vpnGateway: vpnGateway))
    }
    
    func presentReportBug() {
        let viewController = ReportBugViewController(vpnManager: vpnManager)
        viewController.viewModel = ReportBugViewModel(os: "iOS", osVersion: UIDevice.current.systemVersion, propertiesManager: propertiesManager, reportsApiService: ReportsApiService(networking: networking), alertService: alertService, vpnKeychain: vpnKeychain)
        let navigationController = UINavigationController(rootViewController: viewController)
        windowService.present(modal: navigationController)
    }
}

extension NavigationService: ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController {
        return VpnProtocolViewController(viewModel: viewModel)
    }
}

extension NavigationService: NetshieldService {
    func makeNetshieldSelectionViewController(selectedType: NetShieldType, approve: @escaping NetshieldSelectionViewModel.ApproveCallback, onChange: @escaping NetshieldSelectionViewModel.TypeChangeCallback) -> NetshieldSelectionViewController {
        return NetshieldSelectionViewController(viewModel: NetshieldSelectionViewModel(selectedType: selectedType, factory: factory, shouldSelectNewValue: approve, onTypeChange: onChange))
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
            statusViewController.planService = self
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
