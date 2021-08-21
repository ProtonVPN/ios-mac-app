//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_HumanVerification
import ProtonCore_Login
import ProtonCore_ForceUpgrade
import ProtonCore_Networking
import ProtonCore_Services
import Crypto

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
        & TrustKitHelperFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let navigationService: NavigationService
    private let windowService: WindowService
    private let alertService: AlertService

    private let forceUpgradeService: ForceUpgradeDelegate
    private var login: PMLogin?

    init(factory: Factory) {
        appSessionManager = factory.makeAppSessionManager()
        appSessionRefresher = factory.makeAppSessionRefresher()
        navigationService = factory.makeNavigationService()
        windowService = factory.makeWindowService()
        alertService = factory.makeCoreAlertService()        

        forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
    }

    private func finishLgin(data: LoginData) {
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
}

// MARK: LoginService
extension CoreLoginService: LoginService {
    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void) {
        if appSessionManager.loadDataWithoutFetching() {
            appSessionRefresher.refreshData()
        } else { // if no data is stored already, then show spinner and wait for data from the api
            appSessionManager.attemptDataRefreshWithoutLogin(success: {
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
        let login = PMLogin(appName: "ProtonVPN", doh: ApiConstants.doh, apiServiceDelegate: self, forceUpgradeDelegate: forceUpgradeService, minimumAccountType: AccountType.username, signupMode: SignupMode.external, isCloseButtonAvailable: false, isPlanSelectorAvailable: false)
        self.login = login

        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))) { [weak self] result in
            switch result {
            case .dismissed:
                PMLog.ET("Dismissing the Welcome screen without login or signup should not be possible")
            case let .loggedIn(data):
                self?.finishLgin(data: data)
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
    }
}

// MARK: APIServiceDelegate
extension CoreLoginService: APIServiceDelegate {
    var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    var appVersion: String {
        return ApiConstants.appVersion
    }
    var userAgent: String? {
        return ApiConstants.userAgent
    }
    func onUpdate(serverTime: Int64) {
        CryptoUpdateTime(serverTime)
    }
    func isReachable() -> Bool {
        return true
    }
    func onDohTroubleshot() { }
}
