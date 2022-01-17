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

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilengLoginResult {
    case loggedIn
    case notLoggedIn
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func usedDidSignUp(onboardingShowFirstConnection: Bool)
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
        & NetworkingDelegateFactory
        & PropertiesManagerFactory
        & NetworkingFactory
        & DoHVPNFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let windowService: WindowService
    private let networkingDelegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol
    private let doh: DoHVPN

    private var login: LoginAndSignupInterface?

    weak var delegate: LoginServiceDelegate?

    init(factory: Factory) {
        appSessionManager = factory.makeAppSessionManager()
        appSessionRefresher = factory.makeAppSessionRefresher()
        windowService = factory.makeWindowService()
        networkingDelegate = factory.makeNetworkingDelegate()
        propertiesManager = factory.makePropertiesManager()
        networking = factory.makeNetworking()
        doh = factory.makeDoHVPN()
    }

    private func show() {
        let signupAvailability = SignupAvailability.available(parameters: SignupParameters(mode: SignupMode.external, passwordRestrictions: SignupPasswordRestrictions.default, summaryScreenVariant: SummaryScreenVariant.noSummaryScreen))
        let login = LoginAndSignup(appName: "ProtonVPN", clientApp: ClientApp.vpn, doh: doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, isCloseButtonAvailable: false, paymentsAvailability: PaymentsAvailability.notAvailable, signupAvailability: signupAvailability)
        self.login = login

        let finishFlow = WorkBeforeFlow(stepName: LocalizedString.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to uset the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials, completion: completion)
        }

        let variant = WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))
        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: variant, username: nil, performBeforeFlow: finishFlow, customErrorPresenter: nil) { [weak self] (result: LoginResult) -> Void in
            switch result {
            case .dismissed:
                log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
            case .loggedIn:
                self?.delegate?.userDidLogIn()
            case .signedUp:
                self?.delegate?.usedDidSignUp(onboardingShowFirstConnection: true)
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
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
