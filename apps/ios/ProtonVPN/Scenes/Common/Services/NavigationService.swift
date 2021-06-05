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

// MARK: Login Service

protocol LoginServiceFactory {
    func makeLoginService() -> LoginService
}

extension DependencyContainer: LoginServiceFactory {
    func makeLoginService() -> LoginService {
        return makeNavigationService()
    }
}

protocol LoginService {
    func presentLogin(dismissible: Bool, username: String?, errorMessage: String?)
    func presentLogin(dismissible: Bool)
    func presentLogin()
    func presentSignup(dismissible: Bool)
    func presentSignup()
    func presentOnboarding()
    func presentMainInterface()
    // New
    func presentRegistrationForm(viewModel: SignUpFormViewModel)
}

// MARK: Human Verification Service

protocol HumanVerificationServiceFactory {
    func makeHumanVerificationService() -> HumanVerificationService
}

extension DependencyContainer: HumanVerificationServiceFactory {
    func makeHumanVerificationService() -> HumanVerificationService {
        return makeNavigationService()
    }
}

protocol HumanVerificationService {
    func presentHumanVerificationOptionsViewController(viewModel: HumanVerificationOptionsViewModel)
    func goBackToHumanVerificationOptionsViewController()
    func presentVerificationEmail(viewModel: VerificationEmailViewModel)
    func presentVerificationCode(viewModel: VerificationCodeViewModel)
    func presentVerificationSms(viewModel: VerificationSmsViewModel)
    func presentSmsCountryCodeViewController(viewModel: SmsCountryCodeViewModel)
    func presentVerificationCaptcha(viewModel: VerificationCaptchaViewModel)
}

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

class NavigationService {
    
    typealias Factory =
        PropertiesManagerFactory & WindowServiceFactory & VpnKeychainFactory & AlamofireWrapperFactory & VpnApiServiceFactory & AppStateManagerFactory & AppSessionManagerFactory & TrialCheckerFactory & CoreAlertServiceFactory & ReportBugViewModelFactory & AuthApiServiceFactory & UserApiServiceFactory & PaymentsApiServiceFactory & AlamofireWrapperFactory & VpnManagerFactory & UIAlertServiceFactory & SignUpCoordinatorFactory & SignUpFormViewModelFactory & PlanSelectionViewModelFactory & ServicePlanDataServiceFactory & LoginServiceFactory & SubscriptionInfoViewModelFactory & ServicePlanDataStorageFactory & StoreKitManagerFactory & AppSessionRefresherFactory & PlanServiceFactory & VpnGatewayFactory & ProfileManagerFactory & NetshieldServiceFactory & AnnouncementsViewModelFactory & AnnouncementManagerFactory & ConnectionStatusServiceFactory & NetShieldPropertyProviderFactory
    private let factory: Factory
    
    // MARK: Storyboards
    private lazy var launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
    private lazy var mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    private lazy var commonStoryboard = UIStoryboard(name: "Common", bundle: nil)
    private lazy var countriesStoryboard = UIStoryboard(name: "Countries", bundle: nil)
    private lazy var loginStoryboard = UIStoryboard(name: "Login", bundle: nil)
    private lazy var profilesStoryboard = UIStoryboard(name: "Profiles", bundle: nil)
    
    // MARK: Properties
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    lazy var windowService: WindowService = factory.makeWindowService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var authApiService: AuthApiService = factory.makeAuthApiService()
    private lazy var userApiService: UserApiService = factory.makeUserApiService()
    private lazy var paymentsApiService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var alamofireWrapper: AlamofireWrapper = factory.makeAlamofireWrapper()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var uiAlertService: UIAlertService = factory.makeUIAlertService()
    private lazy var servicePlanDataService: ServicePlanDataService = factory.makeServicePlanDataService()
    private lazy var servicePlanDataStorage: ServicePlanDataStorage = factory.makeServicePlanDataStorage()
    private lazy var storeKitManager: StoreKitManager = factory.makeStoreKitManager()
    
    private var trialChecker: TrialChecker?
    
    private lazy var profileManager = {
        return ProfileManager.shared
    }()
    private lazy var connectionBarViewController = { 
        return makeConnectionBarViewController()
    }()
    private lazy var loginViewModel = { [unowned self] in
        return LoginViewModel(factory: factory)
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
        
        attemptSilentLogIn()
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if appSessionManager.vpnGateway != nil {
            trialChecker = factory.makeTrialChecker()
        } else {
            trialChecker = nil
        }
        
        if appSessionManager.sessionStatus == .notEstablished {
            presentOnboarding()
            return
        }
    }
    
    private func attemptSilentLogIn() {
        loginViewModel.logInSilently()
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
    
    private func makeLaunchViewController() -> LaunchViewController? {
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

// MARK: LoginService

extension NavigationService: LoginService {
    
    private func makeLoginViewController(dismissible: Bool, username: String? = nil, errorMessage: String? = nil) -> LoginViewController? {
        if let loginViewController = loginStoryboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
            loginViewController.viewModel = LoginViewModel(dismissible: dismissible, username: username, errorMessage: errorMessage, factory: factory)
            return loginViewController
        }
        return nil
    }
            
    func presentLogin(dismissible: Bool, username: String?, errorMessage: String?) {
        DispatchQueue.main.async { [unowned self] in
            if let loginViewController = self.makeLoginViewController(dismissible: dismissible, username: username, errorMessage: errorMessage) {
                loginViewController.modalPresentationStyle = .fullScreen
                self.windowService.replace(with: loginViewController)
                if !self.propertiesManager.userDataDisclaimerAgreed {
                    self.windowService.present(modal: DataDisclaimerViewController())
                }
            }
        }
    }
    
    func presentLogin(dismissible: Bool) {
        presentLogin(dismissible: dismissible, username: nil, errorMessage: nil)
    }
    
    func presentLogin() {
        presentLogin(dismissible: true)
    }
    
    func presentSignup(dismissible: Bool) {
        // We don't have to retain Coordinator because it adds closures with strong self to created ViewModel callbacks
        let coordinator = factory.makeSignUpCoordinator()
        coordinator.cancelled = {
            self.windowService.dismissModal()
        }
        coordinator.finished = { loggedIn in
            if !loggedIn {
                self.presentLogin()
            } else {
                self.presentMainInterface()
            }
        }
        coordinator.start()
        
        if !propertiesManager.userDataDisclaimerAgreed {
            windowService.present(modal: DataDisclaimerViewController())
        }
    }
    
    func presentSignup() {
        presentSignup(dismissible: true)
    }
    
    func presentOnboarding() {
        self.storeKitManager.subscribeToPaymentQueue() // This ensures that storekit manager will know if there are unfinished transactions
        let onboardingViewModel = OnboardingViewModel(pageViewController: OnboardingPageViewController(), factory: factory)
        let onboardingViewController = OnboardingViewController(viewModel: onboardingViewModel)
        windowService.show(viewController: onboardingViewController)
    }
    
    func presentMainInterface() {
        setupTabs()
    }
    
    // New
    
    func presentRegistrationForm(viewModel: SignUpFormViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let controller = self.loginStoryboard.instantiateViewController(withIdentifier: "SignUpFormViewController") as? SignUpFormViewController else { return }
            controller.viewModel = viewModel 
            
            if self.windowService.navigationStackAvailable {
                self.windowService.addToStack(controller, checkForDuplicates: false)
            } else {
                let nc = UINavigationController(rootViewController: controller)

                nc.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
                nc.navigationBar.shadowImage = UIImage()
                nc.navigationBar.isTranslucent = true
                nc.modalPresentationStyle = .fullScreen
                
                self.windowService.replace(with: nc)
            }
            
        }
    }
    
}

// MARK: - HumanVerificationService

extension NavigationService: HumanVerificationService {
    
    func presentHumanVerificationOptionsViewController(viewModel: HumanVerificationOptionsViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let signUpVerificationCodeViewController = self.loginStoryboard.instantiateViewController(withIdentifier: "SignUpVerificationOptionsViewController") as? HumanVerificationOptionsViewController else { return }
            signUpVerificationCodeViewController.viewModel = viewModel
            let nc = UINavigationController(rootViewController: signUpVerificationCodeViewController)
            nc.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
            nc.navigationBar.shadowImage = UIImage()
            nc.navigationBar.isTranslucent = true
            nc.modalPresentationStyle = .fullScreen
            self.windowService.present(modal: nc)
        }
    }
    
    func goBackToHumanVerificationOptionsViewController() {
        DispatchQueue.main.async { [unowned self] in
            self.windowService.popStackToRoot()
        }
    }
    
    func presentVerificationEmail(viewModel: VerificationEmailViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let verificationViewController = self.loginStoryboard.instantiateViewController(withIdentifier: "VerificationEmailViewController") as? VerificationEmailViewController else { return }
            verificationViewController.viewModel = viewModel
            self.windowService.addToStack(verificationViewController, checkForDuplicates: false)
        }
    }
    
    func presentVerificationCode(viewModel: VerificationCodeViewModel) {
        DispatchQueue.main.async { [unowned self] in            
            guard let verificationCodeViewController = self.loginStoryboard.instantiateViewController(withIdentifier: "VerificationCodeViewController") as? VerificationCodeViewController else {
                return
            }
            verificationCodeViewController.viewModel = viewModel
            self.windowService.addToStack(verificationCodeViewController, checkForDuplicates: false)
        }
    }
    
    func presentVerificationSms(viewModel: VerificationSmsViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let verificationViewController = self.loginStoryboard.instantiateViewController(withIdentifier: "VerificationSmsViewController") as? VerificationSmsViewController else { return }
            verificationViewController.viewModel = viewModel
            self.windowService.addToStack(verificationViewController, checkForDuplicates: false)
        }
    }
    
    func presentSmsCountryCodeViewController(viewModel: SmsCountryCodeViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let viewController = self.loginStoryboard.instantiateViewController(withIdentifier: "SmsCountryCodeViewController") as? SmsCountryCodeViewController else { return }
            viewController.viewModel = viewModel
            let navigationController = UINavigationController(rootViewController: viewController)
            self.windowService.present(modal: navigationController)
            
        }
    }
    func presentVerificationCaptcha(viewModel: VerificationCaptchaViewModel) {
        DispatchQueue.main.async { [unowned self] in
            guard let verificationViewController = self.loginStoryboard.instantiateViewController(withIdentifier: "VerificationCaptchaViewController") as? VerificationCaptchaViewController else { return }
            verificationViewController.viewModel = viewModel
            self.windowService.addToStack(verificationViewController, checkForDuplicates: false)
        }
    }
}

// MARK: - PlanService

extension NavigationService: PlanService {
        
    func makePurchaseCompleteViewController(plan: AccountPlan) -> PurchaseCompleteViewController? {
        if let signUpCompleteViewController = loginStoryboard.instantiateViewController(withIdentifier: "SignUpCompleteViewController") as? PurchaseCompleteViewController {
            signUpCompleteViewController.logInService = self
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
        countriesViewController.viewModel = CountriesViewModel(factory: factory, vpnGateway: vpnGateway, countryService: self, loginService: self)
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
        mapViewController.viewModel = MapViewModel(appStateManager: appStateManager, loginService: self, alertService: alertService, serverStorage: ServerStorageConcrete(), vpnGateway: vpnGateway, vpnKeychain: vpnKeychain, propertiesManager: propertiesManager, connectionStatusService: self)
        mapViewController.connectionBarViewController = makeConnectionBarViewController()
        return mapViewController
    }
}

extension NavigationService: ProfileService {
    func makeProfilesViewController() -> ProfilesViewController {
        let profilesViewController = profilesStoryboard.instantiateViewController(withIdentifier: String(describing: ProfilesViewController.self)) as! ProfilesViewController
        profilesViewController.viewModel = ProfilesViewModel(vpnGateway: vpnGateway, factory: self, loginService: self, alertService: alertService, planService: self, propertiesManager: propertiesManager, connectionStatusService: self, netShieldPropertyProvider: factory.makeNetShieldPropertyProvider())
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
            settingsViewController.viewModel = SettingsViewModel(appStateManager: appStateManager, appSessionManager: appSessionManager, vpnGateway: vpnGateway, alertService: alertService, planService: self, settingsService: self, protocolService: self, vpnKeychain: vpnKeychain, netshieldService: self, connectionStatusService: self, netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(), vpnManager: vpnManager)
            settingsViewController.connectionBarViewController = makeConnectionBarViewController()
            return settingsViewController
        }
        
        return nil
    }
    
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController {
        return WidgetSettingsViewController(viewModel: WidgetSettingsViewModel())
    }
    
    func makeLogSelectionViewController() -> LogSelectionViewController {
        return LogSelectionViewController(viewModel: LogSelectionViewModel(vpnManager: vpnManager, settingsService: self))
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
        viewController.viewModel = ReportBugViewModel(os: "iOS", osVersion: UIDevice.current.systemVersion, propertiesManager: propertiesManager, reportsApiService: ReportsApiService(alamofireWrapper: alamofireWrapper), alertService: alertService, vpnKeychain: vpnKeychain)
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
