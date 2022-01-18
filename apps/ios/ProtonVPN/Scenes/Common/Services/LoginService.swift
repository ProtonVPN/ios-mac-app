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

protocol LoginService: AnyObject {
    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void)
    func showWelcome()
}

// MARK: CoreLoginService
final class CoreLoginService {
    public typealias Factory = AppSessionManagerFactory
        & AppSessionRefresherFactory
        & NavigationServiceFactory
        & WindowServiceFactory
        & CoreAlertServiceFactory
        & NetworkingDelegateFactory
        & PropertiesManagerFactory
        & NetworkingFactory
        & DoHVPNFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let navigationService: NavigationService
    private let windowService: WindowService
    private let alertService: AlertService
    private let networkingDelegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol
    private let doh: DoHVPN

    private var login: LoginAndSignupInterface?

    init(factory: Factory) {
        appSessionManager = factory.makeAppSessionManager()
        appSessionRefresher = factory.makeAppSessionRefresher()
        navigationService = factory.makeNavigationService()
        windowService = factory.makeWindowService()
        alertService = factory.makeCoreAlertService()
        networkingDelegate = factory.makeNetworkingDelegate()
        propertiesManager = factory.makePropertiesManager()
        networking = factory.makeNetworking()
        doh = factory.makeDoHVPN()
    }

    private func show() {
        let signupAvailability = SignupAvailability.available(parameters: SignupParameters(passwordRestrictions: SignupPasswordRestrictions.default, summaryScreenVariant: SummaryScreenVariant.screenVariant(.vpn(SummaryStartButtonText(LocalizedString.loginSummaryButton)))))
        let paymentsAvailability = PaymentsAvailability.available(parameters: PaymentsParameters(listOfIAPIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers, listOfShownPlanNames: ObfuscatedConstants.planNames, reportBugAlertHandler: { [weak self] receipt in
            log.error("Error from payments, showing bug report", category: .iap)
            self?.alertService.push(alert: ReportBugAlert())
        }))
        let login = LoginAndSignup(appName: "ProtonVPN", clientApp: ClientApp.vpn, doh: doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, isCloseButtonAvailable: false, paymentsAvailability: paymentsAvailability, signupAvailability: signupAvailability)
        self.login = login

        let finishFlow = WorkBeforeFlow(stepName: LocalizedString.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to uset the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials, completion: completion)
        }

        let variant = WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))
        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: variant, username: nil, performBeforeFlow: finishFlow, customErrorPresenter: self) { [weak self] (result: LoginResult) -> Void in
            switch result {
            case .dismissed:
                log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
            case .loggedIn, .signedUp:
                self?.navigationService.presentMainInterface()
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
    }

    #if !RELEASE
    private func showEnvironmentSelection() {
        let environmentsViewController = UIStoryboard(name: "Environments", bundle: nil).instantiateViewController(withIdentifier: "EnvironmentsViewController") as! EnvironmentsViewController
        environmentsViewController.propertiesManager = propertiesManager
        environmentsViewController.doh = doh
        environmentsViewController.delegate = self
        windowService.show(viewController: UINavigationController(rootViewController: environmentsViewController))
    }
    #endif
}

// MARK: LoginErrorPresenter
extension CoreLoginService: LoginErrorPresenter {
    func willPresentError(error: LoginError, from: UIViewController) -> Bool {
        switch error {
        case .generic(_, _, ProtonVpnError.subuserWithoutSessions):
            alertService.push(alert: SubuserWithoutConnectionsAlert())
            return true
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

#if !RELEASE
extension CoreLoginService: EnvironmentsViewControllerDelegate {
    func userDidSelectContinue() {
        show()
    }
}
#endif

extension AuthCredentials {
    convenience init(_ data: LoginData) {
        switch data {
        case let .credential(credential):
            self.init(credential)
        case let .userData(userData):
            self.init(version: 0, username: userData.credential.userName, accessToken: userData.credential.accessToken, refreshToken: userData.credential.refreshToken, sessionId: userData.credential.sessionID, userId: userData.credential.userID, expiration: userData.credential.expiration, scopes: userData.scopes.compactMap({ AuthCredentials.Scope(rawValue: $0) }))
        }
    }
}
