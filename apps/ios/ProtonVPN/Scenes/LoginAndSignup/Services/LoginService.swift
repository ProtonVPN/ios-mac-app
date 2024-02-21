//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import LegacyCommon
import ProtonCoreDataModel
import ProtonCoreLogin
import ProtonCoreLoginUI
import ProtonCoreNetworking
import ProtonCorePayments
import ProtonCorePushNotifications
import ProtonCoreUIFoundations
import UIKit
import VPNShared
import Strings

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilentLoginResult {
    case loggedIn
    case notLoggedIn
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func userDidSignUp()
}

protocol LoginService: AnyObject {
    var delegate: LoginServiceDelegate? { get set }

    func attemptSilentLogIn(completion: @escaping (SilentLoginResult) -> Void)
    func showWelcome(initialError: String?, withOverlayViewController: UIViewController?)
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
        & PushNotificationServiceFactory

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
    private let pushNotificationService: PushNotificationServiceProtocol

    private lazy var loginInterface: LoginAndSignupInterface = makeLoginInterface()

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
        pushNotificationService = factory.makePushNotificationService()
    }

    private func makeLoginInterface() -> LoginAndSignupInterface {
        let signupParameters = SignupParameters(separateDomainsButton: true, passwordRestrictions: .default, summaryScreenVariant: .noSummaryScreen)
        let signupAvailability = SignupAvailability.available(parameters: signupParameters)
        let login = LoginAndSignup.init(appName: "Proton VPN",
                                        clientApp: .vpn,
                                        apiService: networking.apiService,
                                        minimumAccountType: AccountType.username,
                                        isCloseButtonAvailable: false,
                                        paymentsAvailability: PaymentsAvailability.notAvailable,
                                        signupAvailability: signupAvailability)
        return login
    }

    private func finishFlow() -> WorkBeforeFlow {
        WorkBeforeFlow(stepName: Localizable.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping @MainActor (Result<Void, Error>) -> Void) -> Void in
            // attempt to use the login data to log in the app
            let authCredentials = AuthCredentials(data)
            Task { @MainActor [weak self] in
                do {
                    try await self?.appSessionManager.finishLogin(authCredentials: authCredentials)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func helpDecorator(input: [[HelpItem]]) -> [[HelpItem]] {
        let reportBugItem = HelpItem.custom(icon: IconProvider.bug, title: Localizable.reportBug, behaviour: { [weak self] viewController in
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
        // loginInterface should not be retained, but recreated after
        // each use. But not all LoginResults signal and end of the process,
        // so we only renew it in some cases
        switch result {
        case .dismissed:
            log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
            loginInterface = makeLoginInterface()
        case .loginStateChanged(.loginFinished):
            delegate?.userDidLogIn()
            loginInterface = makeLoginInterface()
        case .signupStateChanged(.signupFinished):
            delegate?.userDidSignUp()
            loginInterface = makeLoginInterface()
        case .loginStateChanged(.dataIsAvailable(let loginData)), .signupStateChanged(.dataIsAvailable(let loginData)):
            log.debug("Login or signup process in progress", category: .app)
            // Update the session id in the networking stack after login
            let uid = loginData.getCredential.UID
            networking.apiService.setSessionUID(uid: uid)
            pushNotificationService.didLoginWithUID(uid)
        }
    }

    private func show(initialError: String?, withOverlayViewController: UIViewController?) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
        #endif
        
        let loginResultCompletion = { [weak self] (result: LoginAndSignupResult) -> Void in
            self?.processLoginResult(result: result)
        }
        let customization = LoginCustomizationOptions(username: nil,
                                                      performBeforeFlow: finishFlow(),
                                                      customErrorPresenter: self,
                                                      initialError: initialError,
                                                      helpDecorator: helpDecorator)
        let variant: WelcomeScreenVariant = .vpn(WelcomeScreenTexts(body: Localizable.welcomeBody))
        let welcomeViewController = loginInterface.welcomeScreenForPresentingFlow(variant: variant,
                                                                                  customization: customization,
                                                                                  updateBlock: loginResultCompletion)
        windowService.show(viewController: welcomeViewController)
        if initialError != nil {
            loginInterface.presentLoginFlow(over: welcomeViewController, customization: customization, updateBlock: loginResultCompletion)
        }
        if let overlay = withOverlayViewController {
            welcomeViewController.present(overlay, animated: false)
        }
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
            let role = propertiesManager.userRole
            alertService.push(alert: SubuserWithoutConnectionsAlert(role: role))
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
                    Task { @MainActor in
                        try? await appSessionManager.loadDataWithoutLogin()
                        completion(.notLoggedIn)
                    }
                }
            }
        }

        if appSessionManager.sessionStatus == .established {
            completion(.loggedIn)
        }
    }

    func showWelcome(initialError: String?, withOverlayViewController overlayViewController: UIViewController?) {
        DispatchQueue.main.async {
            #if !RELEASE
            self.showEnvironmentSelection()
            #else
            self.show(initialError: initialError, withOverlayViewController: overlayViewController)
            #endif
        }
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
        show(initialError: nil, withOverlayViewController: nil)
    }
}
#endif
