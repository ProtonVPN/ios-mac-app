//
//  LoginViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

import AppKit
import Foundation
import LegacyCommon
import ProtonCoreLogin
import ProtonCoreNetworking
import ProtonCoreAuthentication
import ProtonCoreFeatureFlags
import ProtonCoreServices
import ProtonCoreObservability
import VPNShared
import Strings

final class LoginViewModel {
    
    typealias Factory = NavigationServiceFactory &
                        PropertiesManagerFactory &
                        AppSessionManagerFactory &
                        CoreAlertServiceFactory &
                        UpdateManagerFactory &
                        ProtonReachabilityCheckerFactory &
                        NetworkingFactory &
                        SystemExtensionManagerFactory
    private let factory: Factory
    
    private lazy var apiService: APIService = factory.makeNetworking().apiService
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var protonReachabilityChecker: ProtonReachabilityChecker = factory.makeProtonReachabilityChecker()
    private lazy var loginService: Login = LoginService(api: apiService,
                                                        clientApp: .vpn,
                                                        minimumAccountType: AccountType.username,
                                                        ssoCallbackScheme: AppConstants.DeepLinking.deepLinkScheme)
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    var logInInProgress: (() -> Void)?
    var logInFailure: ((String?, Int?) -> Void)?
    var logInFailureWithSupport: ((String?) -> Void)?
    var checkInProgress: ((Bool) -> Void)?
    var twoFactorRequired: (() -> Void)?
    var ssoChallengeReceived: ((URLRequest) -> Void)?
    var initialError: String?

    private(set) var isTwoFactorStep: Bool = false

    init (factory: Factory, initialError: String? = nil) {
        self.factory = factory
        self.initialError = initialError
    }
    
    var startOnBoot: Bool {
        return propertiesManager.startOnBoot
    }
    
    func startOnBoot(enabled: Bool) {
        propertiesManager.startOnBoot = enabled
    }
    
    func logInSilently() {
        logInInProgress?()
        appSessionManager.attemptSilentLogIn { result in
            switch result {
            case .success:
                NSApp.setActivationPolicy(.accessory)
                self.silentlyCheckForUpdates()
                // Don't switch to smart protocol or show sysex tour if we are launching minimised
                self.checkSysexApprovalAndAdjustProtocol(shouldDefaultToSmartIfPossible: false, shouldStartTour: false)
            case let .failure(error):
                self.specialErrorCaseNotification(error)
                self.navService.handleSilentLoginFailure()
            }
        }
    }
    
    func logInAppeared() {
        guard initialError == nil else {
            logInFailure?(initialError, nil)
            return
        }
        logInInProgress?()
        appSessionManager.attemptSilentLogIn { result in
            switch result {
            case .success:
                self.silentlyCheckForUpdates()
                // Don't switch to smart protocol or show sysex tour if we are logging in automatically
                self.checkSysexApprovalAndAdjustProtocol(shouldDefaultToSmartIfPossible: false, shouldStartTour: false)
            case let .failure(error):
                self.specialErrorCaseNotification(error)

                if case ProtonVpnError.userCredentialsMissing = error {
                    self.logInFailure?(nil, nil)
                    return
                }
                self.logInFailure?(error.localizedDescription, nil)
            }
        }
    }
    
    func logIn(username: String, password: String) {
        logInInProgress?()
        loginService.login(
            username: username,
            password: password,
            intent: FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.externalSSO, reloadValue: true) ? .proton : .auto,
            challenge: nil
        ) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
    }
    
    func logInWithSSO(username: String) {
        logInInProgress?()
        loginService.login(
            username: username,
            password: "",
            intent: .sso,
            challenge: nil
        ) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
    }
    
    func identifyAndProcessSSOResponseToken(from url: URL?, username: String) -> Bool {
        guard let token = getSSOTokenFromURL(url: url) else { return false }
        loginService.processResponseToken(idpEmail: username, responseToken: token) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
        return true
    }
    
    private func getSSOTokenFromURL(url: URL?) -> SSOResponseToken? {
        guard let url, url.path == "/sso/login" else { return nil }
        
        var components = URLComponents()
        components.query = url.fragment
        
        guard let items = components.queryItems,
              let token = (items.first { $0.name == "token" }?.value),
              let uid = (items.first { $0.name == "uid" }?.value) else {
            return nil
        }
        
        return .init(token: token, uid: uid)
    }
    
    func isProtonPage(url: URL?) -> Bool {
        guard let url else { return false }
        let hosts = [
            apiService.dohInterface.getAccountHost(),
            apiService.dohInterface.getCurrentlyUsedHostUrl(),
            apiService.dohInterface.getHumanVerificationV3Host(),
            apiService.dohInterface.getCaptchaHostUrl()
        ]
        return hosts.contains(where: url.absoluteString.contains)
    }

    func provide2FACode(code: String) {
        logInInProgress?()
        loginService.provide2FACode(code) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
    }

    func cancelTwoFactor() {
        isTwoFactorStep = false
    }

    func updateAvailableDomains() {
        loginService.updateAllAvailableDomains(type: AvailableDomainsType.login) { _ in }
    }

    private func handleLoginResult(result: Result<LoginStatus, LoginError>) {
        switch result {
        case let .success(status):
            switch status {
            case let .finished(data):
                ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .successful))
                appSessionManager.finishLogin(authCredentials: AuthCredentials(data.getCredential), success: {
                    // Strongly capture `self` in this closure to delay de-allocation until sysex tour is shown
                    self.silentlyCheckForUpdates()
                    // On manual login, show sysex tour if needed and/or switch to smart protocol if possible
                    self.checkSysexApprovalAndAdjustProtocol(shouldDefaultToSmartIfPossible: true, shouldStartTour: true)
                }, failure: { [weak self] error in
                    self?.handleError(error: error)
                })
            case let .ssoChallenge(ssoResponse):
                Task {
                    switch await loginService.getSSORequest(challenge: ssoResponse) {
                    case (let request?, _):
                        ssoChallengeReceived?(request)
                    case (_, let error?):
                        handleError(error: error)
                    default:
                        break
                    }
                }
            case .ask2FA:
                isTwoFactorStep = true
                twoFactorRequired?()
            case .askSecondPassword, .chooseInternalUsernameAndCreateInternalAddress:
                log.error("Unsupported login scenario", category: .app, metadata: ["result": "\(result)"])
                logInFailure?(Localizable.loginUnsupportedState, nil)
            }
        case let .failure(error):
            ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .failed))
            handleLoginError(error: error)
        }
    }

    /// Check sysex installation state. Fall back to IKE if sysex approval is missing but required by current protocol.
    /// - Parameter shouldDefaultToSmartIfPossible: If system extensions are approved, sets default protocol to smart.
    /// - Parameter shouldStartTour: Controls whether the sysex tour is shown, if approval is required.
    private func checkSysexApprovalAndAdjustProtocol(shouldDefaultToSmartIfPossible: Bool, shouldStartTour: Bool) {
        sysexManager.installOrUpdateExtensionsIfNeeded(shouldStartTour: shouldStartTour) { result in
            switch result {
            case .success:
                if shouldDefaultToSmartIfPossible {
                    self.propertiesManager.smartProtocol = true
                }
            case .failure:
                let currentProtocol = self.propertiesManager.connectionProtocol
                if currentProtocol.requiresSystemExtension {
                    // Forcefully revert default protocol to IKE - current protocol is unusable
                    log.warning("\(currentProtocol) requires sysex (not installed), reverting to IKEv2", category: .sysex)
                    self.propertiesManager.connectionProtocol = .vpnProtocol(.ike)
                }
            }
        }
    }

    private func handleLoginError(error: LoginError) {
        // some login errors need to be handle in a specific way
        switch error {
        case let .invalidAccessToken(message: message):
            // after entering wrong 2FA code 3 times the access token gets invalidated
            // the users cannot continue entering the 2FA code, they need to start over
            // the state is reset back to the username + password form and error is shown
            isTwoFactorStep = false
            logInFailure?(message, nil)
        case let .invalidCredentials(message: message), let .invalid2FACode(message: message):
            // invalid credentials or 2FA code entered, show the most specific error message
            logInFailure?(message, nil)
        case let .generic(message, code, _) where code == APIErrorCode.switchToSSOError:
            logInFailure?(message, code)
        case let .generic(_, _, originalError):
            // if the error is a response error and the underlying error is a network or TLS error convert it to the app network error
            // this is needed so the basic error handling logic shows an alert that offers troubleshooting to the users
            if let responseError = originalError as? ResponseError, let underlyingError = responseError.underlyingError, underlyingError.isNetworkError || underlyingError.isTlsError {
                handleError(error: NetworkError.error(forCode: underlyingError.code))
                return
            }

            // otherwise just convert the login error to a classic error with the error code and the user facing error message
            handleError(error: NSError(code: error.bestShotAtReasonableErrorCode, localizedDescription: error.userFacingMessageInLogin))
        default:
            handleError(error: NSError(code: error.bestShotAtReasonableErrorCode, localizedDescription: error.userFacingMessageInLogin))
        }
    }

    private func handleError(error: Error) {
        DispatchQueue.main.async {
            self.specialErrorCaseNotification(error)

            let nsError = error as NSError
            if nsError.isTlsError || nsError.isNetworkError {
                let alert = UnreachableNetworkAlert(error: error, troubleshoot: { [weak self] in
                    self?.alertService.push(alert: ConnectionTroubleshootingAlert())
                })
                self.alertService.push(alert: alert)
                self.logInFailure?(nil, nil)
            } else if case ProtonVpnError.subuserWithoutSessions = error {
                let role = self.propertiesManager.userRole
                self.alertService.push(alert: SubuserWithoutConnectionsAlert(role: role))
                self.isTwoFactorStep = false
                self.logInFailure?(nil, nil)
            } else {
                self.logInFailure?(error.localizedDescription, nil)
            }
        }
    }
    
    private func specialErrorCaseNotification(_ error: Error) {
        if (error as NSError).code == NetworkErrorCode.timedOut ||
            (error as NSError).code == ApiErrorCode.apiVersionBad ||
            (error as NSError).code == ApiErrorCode.appVersionBad {
            logInFailureWithSupport?(error.localizedDescription)
        }
    }
    
    private func silentlyCheckForUpdates() {
        updateManager.checkForUpdates(appSessionManager, silently: true)
    }
    
    func keychainHelpAction() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.supportCommonIssues)
    }
    
    func createAccountAction() {
        checkInProgress?(true)

        protonReachabilityChecker.check { [weak self] reachable in
            self?.checkInProgress?(false)

            if reachable {
                SafariService().open(url: CoreAppConstants.ProtonVpnLinks.signUp)
            } else {
                self?.alertService.push(alert: ProtonUnreachableAlert())
            }
        }
    }

    var helpPopoverViewModel: HelpPopoverViewModel {
        return HelpPopoverViewModel(navigationService: navService)
    }
}
