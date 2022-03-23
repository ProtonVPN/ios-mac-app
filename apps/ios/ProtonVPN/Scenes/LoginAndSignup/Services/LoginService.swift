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

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilengLoginResult {
    case loggedIn
    case notLoggedIn
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func userDidSignUp(onboardingShowFirstConnection: Bool)
}

protocol LoginService: AnyObject {
    var delegate: LoginServiceDelegate? { get set }

    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void)
    func showWelcome()
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

    private var login: LoginAndSignupInterface?

    weak var delegate: LoginServiceDelegate?

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
    }

    private func show() { // swiftlint:disable:this function_body_length
        let signupAvailability = SignupAvailability.available(parameters: SignupParameters(passwordRestrictions: SignupPasswordRestrictions.default, summaryScreenVariant: SummaryScreenVariant.noSummaryScreen))
        let login = LoginAndSignup(appName: "ProtonVPN", clientApp: ClientApp.vpn, doh: doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, isCloseButtonAvailable: false, paymentsAvailability: PaymentsAvailability.notAvailable, signupAvailability: signupAvailability)
        self.login = login

        var onboardingShowFirstConnection = true
        let finishFlow = WorkBeforeFlow(stepName: LocalizedString.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to use the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials) { [weak self] result in
                switch result {
                case .success:
                    self?.coreApiService.getApiFeature(feature: .onboardingShowFirstConnection) { (result: Result<Bool, Error>) in
                        switch result {
                        case let .success(flag):
                            onboardingShowFirstConnection = flag
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

        let variant = WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))
        let customization = LoginCustomizationOptions(username: nil, performBeforeFlow: finishFlow, customErrorPresenter: self, helpDecorator: { input in
            let reportBugItem = HelpItem.custom(icon: UIImage(named: "ic-bug")!, title: LocalizedString.reportBug, behaviour: { [weak self] viewController in
                self?.settingsService.presentReportBug()
            })
            var result = [[HelpItem]]()
            var currentContent: [HelpItem]
            if input.first != nil {
                currentContent = input.first!
                currentContent.append(reportBugItem)
            } else {
                currentContent = [reportBugItem]
            }
            result.append(currentContent)
            result.append(contentsOf: input.dropFirst())
            return result
        })
        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: variant, customization: customization) { [weak self] (result: LoginResult) -> Void in
            switch result {
            case .dismissed:
                log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
            case .loggedIn:
                self?.delegate?.userDidLogIn()
            case .signedUp:
                self?.delegate?.userDidSignUp(onboardingShowFirstConnection: onboardingShowFirstConnection)
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
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
    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void) {
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

    func showWelcome() {
        #if !RELEASE
        showEnvironmentSelection()
        #else
        show()
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
        show()
    }
}
#endif
