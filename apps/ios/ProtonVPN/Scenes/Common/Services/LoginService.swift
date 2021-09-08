//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_Login
import ProtonCore_Networking

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

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let navigationService: NavigationService
    private let windowService: WindowService
    private let alertService: AlertService
    // swiftlint:disable weak_delegate
    private let networkingDelegate: NetworkingDelegate
    // swiftlint:enable weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol

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
    }

    private func show() {
        let login = LoginAndSignup(appName: "ProtonVPN", doh: ApiConstants.doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, signupMode: SignupMode.external, isCloseButtonAvailable: false)
        self.login = login

        let variant = WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))
        let finishLogin: WorkBeforeFlowCompletion = { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to uset the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials) { result in
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case .success:
                    completion(.success)
                }
            }
        }
        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: variant, username: nil, performBeforeFlowCompletion: finishLogin) { [weak self] result in
            switch result {
            case .dismissed:
                PMLog.ET("Dismissing the Welcome screen without login or signup should not be possible")
            case .loggedIn:
                self?.navigationService.presentMainInterface()
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
    }

    #if !RELEASE
    private func showEnvironmentSelection() {
        let environmentsViewController = UIStoryboard(name: "Common", bundle: nil).instantiateViewController(withIdentifier: "EnvironmentsViewController") as! EnvironmentsViewController
        environmentsViewController.propertiesManager = propertiesManager
        environmentsViewController.delegate = self
        windowService.show(viewController: UINavigationController(rootViewController: environmentsViewController))
    }
    #endif
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
