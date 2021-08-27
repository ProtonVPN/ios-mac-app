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

    private var login: PMLogin?

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

    private func finishLogin(data: LoginData) {
        // login / signup flow is dismisse dat this point, show the generic loading screen
        if let launchViewController = navigationService.makeLaunchViewController() {
            launchViewController.mode = .immediate
            windowService.show(viewController: launchViewController)
        }

        // attempt to uset the login data to lg in the app
        let authCredentials = AuthCredentials(version: 0, username: data.user.name ?? "", accessToken: data.credential.accessToken, refreshToken: data.credential.refreshToken, sessionId: data.credential.sessionID, userId: data.user.ID, expiration: data.credential.expiration, scopes: data.scopes.compactMap({ AuthCredentials.Scope(rawValue: $0) }))

        appSessionManager.finishLogin(authCredentials: authCredentials) { [weak self] result in
            switch result {
            case let .failure(error):
                self?.showError(error)
            case .success:
                self?.navigationService.presentMainInterface()
            }
        }
    }

    private func showError(_ error: Error) {
        PMLog.ET(error.localizedDescription)

        if error.isTlsError || error.isNetworkError {
            let alert = UnreachableNetworkAlert(error: error, troubleshoot: { [weak self] in
                self?.alertService.push(alert: ConnectionTroubleshootingAlert())
            })
            alert.dismiss = { [weak self] in
                self?.showWelcome()
            }
            alertService.push(alert: alert)

        } else {
            let alert = ErrorNotificationAlert(error: error)
            alert.dismiss = { [weak self] in
                self?.showWelcome()
            }
            alertService.push(alert: alert)
        }
    }

    private func show() {
        let login = PMLogin(appName: "ProtonVPN", doh: ApiConstants.doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, signupMode: SignupMode.external, isCloseButtonAvailable: false, isPlanSelectorAvailable: false)
        self.login = login

        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))) { [weak self] result in
            switch result {
            case .dismissed:
                PMLog.ET("Dismissing the Welcome screen without login or signup should not be possible")
            case let .loggedIn(data):
                self?.finishLogin(data: data)
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
    }

    #if !RELEASE
    private func showEnvironmentSelection() {
        let environmentsViewController = EnvironmentsViewController(endpoints: [ApiConstants.liveURL] + ObfuscatedConstants.internalUrls)
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
            appSessionManager.attemptSilentLogIn(success: {
                completion(.loggedIn)
            }, failure: { [appSessionManager] _ in
                appSessionManager.loadDataWithoutLogin(success: {
                    completion(.notLoggedIn)
                }, failure: { _ in
                    completion(.notLoggedIn)
                })
            })
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
    func userDidSelectEndpoint(endpoint: String) {
        propertiesManager.apiEndpoint = endpoint
        show()
    }
}
#endif
