//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_DataModel
import ProtonCore_Login
import ProtonCore_LoginUI
import ProtonCore_Networking
import ProtonCore_Payments
import UIKit

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilentLoginResult {
    case loggedIn
    case notLoggedIn
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func userDidSignUp(onboardingShowFirstConnection: Bool)
}

protocol LoginService: AnyObject {
    var delegate: LoginServiceDelegate? { get set }

    func attemptSilentLogIn(completion: @escaping (SilentLoginResult) -> Void)
    func showWelcome(initialError: String?)
}

// MARK: CoreLoginService

final class CoreLoginService {
    typealias Factory = AppSessionManagerFactory
        & AppSessionRefresherFactory
        & WindowServiceFactory
        & CoreAlertServiceFactory
        & NetworkingDelegateFactory
        & PropertiesManagerFactory
        & NetworkingFactory
        & DoHVPNFactory
        & CoreApiServiceFactory
        & SettingsServiceFactory
        & VpnApiServiceFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let windowService: WindowService
    private let alertService: AlertService
    private let networkingDelegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol
    private let doh: DoHVPN
    private let coreApiService: CoreApiService
    private let settingsService: SettingsService
    private let informativeModalChecker: InformativeModalChecker

    private lazy var loginInterface: LoginAndSignupInterface = {
        let signupParameters = SignupParameters(passwordRestrictions: .default, summaryScreenVariant: .noSummaryScreen)
        let signupAvailability = SignupAvailability.available(parameters: signupParameters)
        let login = LoginAndSignup(appName: "Proton VPN",
                                   clientApp: .vpn,
                                   doh: doh,
                                   apiServiceDelegate: networking,
                                   forceUpgradeDelegate: networkingDelegate,
                                   humanVerificationVersion: networkingDelegate.version,
                                   minimumAccountType: AccountType.username,
                                   isCloseButtonAvailable: false,
                                   paymentsAvailability: PaymentsAvailability.notAvailable,
                                   signupAvailability: signupAvailability)
        return login
    }()

    weak var delegate: LoginServiceDelegate?

    var onboardingShowFirstConnection = true

    init(factory: Factory) {
        appSessionManager = factory.makeAppSessionManager()
        appSessionRefresher = factory.makeAppSessionRefresher()
        windowService = factory.makeWindowService()
        alertService = factory.makeCoreAlertService()
        networkingDelegate = factory.makeNetworkingDelegate()
        propertiesManager = factory.makePropertiesManager()
        networking = factory.makeNetworking()
        doh = factory.makeDoHVPN()
        coreApiService = factory.makeCoreApiService()
        settingsService = factory.makeSettingsService()
        informativeModalChecker = InformativeModalChecker(factory: factory)
    }

    private func finishFlow() -> WorkBeforeFlow {
        WorkBeforeFlow(stepName: LocalizedString.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to use the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials) { [weak self] result in
                switch result {
                case .success:
                    self?.coreApiService.getApiFeature(feature: .onboardingShowFirstConnection) { (result: Result<Bool, Error>) in
                        switch result {
                        case let .success(flag):
                            self?.onboardingShowFirstConnection = flag
                            completion(.success(()))
                        case let .failure(error):
                            log.error("Failed to get onboardingShowFirstConnection flag, using default value", category: .app, metadata: ["error": "\(error)"])
                            completion(.success(()))
                        }
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    private func helpDecorator(input: [[HelpItem]]) -> [[HelpItem]] {
        let reportBugItem = HelpItem.custom(icon: UIImage(named: "ic-bug")!, title: LocalizedString.reportBug, behaviour: { [weak self] viewController in
            self?.settingsService.presentReportBug()
        })
        var result = input
        if !result.isEmpty {
            result[0].append(reportBugItem)
        } else {
            result = [[reportBugItem]]
        }
        return result
    }

    private func processLoginResult(result: LoginAndSignupResult) {
        switch result {
        case .dismissed:
            log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
        case .loginStateChanged(.loginFinished):
            delegate?.userDidLogIn()
        case .signupStateChanged(.signupFinished):
            delegate?.userDidSignUp(onboardingShowFirstConnection: onboardingShowFirstConnection)
        case .loginStateChanged(.dataIsAvailable), .signupStateChanged(.dataIsAvailable):
            log.debug("Login or signup process in progress")
        }
    }

    private func show(initialError: String?) {
        let loginResultCompletion = { [weak self] (result: LoginAndSignupResult) -> Void in
            self?.processLoginResult(result: result)
        }
        let customization = LoginCustomizationOptions(username: nil,
                                                      performBeforeFlow: finishFlow(),
                                                      customErrorPresenter: self,
                                                      initialError: initialError,
                                                      helpDecorator: helpDecorator)
        let variant: WelcomeScreenVariant = .vpn(WelcomeScreenTexts(body: LocalizedString.welcomeBody))
        let welcomeViewController = loginInterface.welcomeScreenForPresentingFlow(variant: variant,
                                                                                  customization: customization,
                                                                                  updateBlock: loginResultCompletion)
        windowService.show(viewController: welcomeViewController)
        if initialError != nil {
            loginInterface.presentLoginFlow(over: welcomeViewController, customization: customization, updateBlock: loginResultCompletion)
        }
        informativeModalChecker.presentInformativeViewController(on: welcomeViewController)
    }

    private func convertError(from error: Error) -> Error {
        // try to get the real error from the Core response error
        guard let responseError = error as? ResponseError, let underlyingError = responseError.underlyingError else {
            return error
        }

        // if it is networking or tls error convert it to the vpncore
        // to get a localized error message from the project's translations
        if underlyingError.isNetworkError || underlyingError.isTlsError {
            return NetworkError.error(forCode: underlyingError.code)
        }

        return underlyingError
    }
}

// MARK: LoginErrorPresenter
extension CoreLoginService: LoginErrorPresenter {
    func willPresentError(error: LoginError, from: UIViewController) -> Bool {
        switch error {
        case .generic(_, _, ProtonVpnError.subuserWithoutSessions):
            alertService.push(alert: SubuserWithoutConnectionsAlert())
            return true
        case let .generic(_, code: _, originalError: originalError):

            // show a custom alert with a way to show the troubleshooting screen
            // for networking and tls errors
            let error = convertError(from: originalError)
            if error.isTlsError || error.isNetworkError {
                alertService.push(alert: UnreachableNetworkAlert(error: error, troubleshoot: { [weak self] in
                    self?.alertService.push(alert: ConnectionTroubleshootingAlert())
                }))
                return true
            }

            return false
        default:
            return false
        }
    }

    func willPresentError(error: SignupError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: AvailabilityError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: SetUsernameError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: CreateAddressError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: CreateAddressKeysError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: StoreKitManagerErrors, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: ResponseError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: Error, from: UIViewController) -> Bool {
        return false
    }
}

// MARK: LoginService

extension CoreLoginService: LoginService {
    func attemptSilentLogIn(completion: @escaping (SilentLoginResult) -> Void) {
        if appSessionManager.loadDataWithoutFetching() {
            appSessionRefresher.refreshData()
        } else { // if no data is stored already, then show spinner and wait for data from the api
            appSessionManager.attemptSilentLogIn { [appSessionManager] result in
                switch result {
                case .success:
                    completion(.loggedIn)
                case .failure:
                    appSessionManager.loadDataWithoutLogin(success: {
                        completion(.notLoggedIn)
                    }, failure: { _ in
                        completion(.notLoggedIn)
                    })
                }
            }
        }

        if appSessionManager.sessionStatus == .established {
            completion(.loggedIn)
        }
    }

    func showWelcome(initialError: String?) {
        #if !RELEASE
        showEnvironmentSelection()
        #else
        show(initialError: initialError)
        #endif
    }
}

// MARK: Environment selection

#if !RELEASE
extension CoreLoginService: EnvironmentsViewControllerDelegate {
    private func showEnvironmentSelection() {
        let environmentsViewController = UIStoryboard(name: "Environments", bundle: nil).instantiateViewController(withIdentifier: "EnvironmentsViewController") as! EnvironmentsViewController
        environmentsViewController.propertiesManager = propertiesManager
        environmentsViewController.doh = doh
        environmentsViewController.delegate = self
        windowService.show(viewController: UINavigationController(rootViewController: environmentsViewController))
    }

    func userDidSelectContinue() {
        show(initialError: nil)
    }
}
#endif
