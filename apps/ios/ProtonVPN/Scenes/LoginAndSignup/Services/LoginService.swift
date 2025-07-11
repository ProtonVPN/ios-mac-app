//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

import Dependencies

import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreLogin
import ProtonCoreLoginUI
import ProtonCoreNetworking
import ProtonCorePayments
import ProtonCorePushNotifications
import ProtonCoreUIFoundations

import CommonNetworking
import LegacyCommon
import Settings
import Strings
import VPNAppCore
import VPNShared

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilentLoginResult {
    case loggedIn
    case notLoggedIn
}

enum LoginFlowType {
    case normal
    case credentiallessUpsell
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func userDidSignUp()
}

protocol LoginService: AnyObject {
    var delegate: LoginServiceDelegate? { get set }

    func attemptSilentLogIn(completion: @escaping (SilentLoginResult) -> Void)
    func showWelcome(initialError: String?, withOverlayViewController: UIViewController?)
    func presentLoginFlow(over viewController: UIViewController, flow: LoginFlowType)
    func presentSignUpFlow(over viewController: UIViewController, flow: LoginFlowType)
}

// MARK: CoreLoginService

final class CoreLoginService {
    typealias Factory = AppSessionManagerFactory
        & AppSessionRefresherFactory
        & CoreAlertServiceFactory
        & NetworkingDelegateFactory
        & NetworkingFactory
        & PropertiesManagerFactory
        & PushNotificationServiceFactory
        & SettingsServiceFactory
        & VpnApiServiceFactory
        & WindowServiceFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let windowService: WindowService
    private let alertService: AlertService
    private let networkingDelegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol
    private let doh: DoHVPN
    private let settingsService: SettingsService
    private let pushNotificationService: PushNotificationServiceProtocol

    private lazy var loginInterface: LoginAndSignupInterface = makeLoginInterface()
    private var banner: PMBanner?

    weak var delegate: LoginServiceDelegate?

    init(factory: Factory) {
        self.doh = Dependency(\.dohConfiguration).wrappedValue
        self.appSessionManager = factory.makeAppSessionManager()
        self.appSessionRefresher = factory.makeAppSessionRefresher()
        self.windowService = factory.makeWindowService()
        self.alertService = factory.makeCoreAlertService()
        self.networkingDelegate = factory.makeNetworkingDelegate()
        self.propertiesManager = factory.makePropertiesManager()
        self.networking = factory.makeNetworking()
        self.settingsService = factory.makeSettingsService()
        self.pushNotificationService = factory.makePushNotificationService()
    }

    private func makeLoginInterface(isCloseButtonAvailable: Bool = false) -> LoginAndSignupInterface {
        let signupParameters = SignupParameters(separateDomainsButton: true, passwordRestrictions: .default, summaryScreenVariant: .noSummaryScreen)
        let signupAvailability = SignupAvailability.available(parameters: signupParameters)

        let login = LoginAndSignup(
            appName: "Proton VPN",
            clientApp: .vpn,
            apiService: networking.apiService,
            minimumAccountType: AccountType.username,
            isCloseButtonAvailable: isCloseButtonAvailable,
            paymentsAvailability: PaymentsAvailability.notAvailable,
            signupAvailability: signupAvailability
        )
        return login
    }

    private func finishFlow() -> WorkBeforeFlow {
        WorkBeforeFlow(stepName: Localizable.loginFetchVpnData) { [weak self] data, completion in
            // attempt to use the login data to log in the app
            let authCredentials = AuthCredentials(data)
            Task { @MainActor [weak self] in
                do {
                    @Dependency(\.userSettingsClient) var userSettingsClient
                    self?.propertiesManager.userSettings = try await userSettingsClient.fetchUserSettings(authCredentials)
                    try await self?.appSessionManager.finishLogin(authCredentials: authCredentials)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func helpDecorator(input: [[HelpItem]]) -> [[HelpItem]] {
        let reportBugItem = HelpItem.custom(icon: IconProvider.bug, title: Localizable.reportBug, behaviour: { [weak self] _ in
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

    private func processLoginResult(result: LoginAndSignupResult, for flow: LoginFlowType) {
        // loginInterface should not be retained, but recreated after
        // each use. But not all LoginResults signal and end of the process,
        // so we only renew it in some cases
        switch result {
        case .dismissed:
            loginInterface = makeLoginInterface()
        case .loginStateChanged(.loginFinished):
            switch flow {
            case .normal:
                delegate?.userDidLogIn()
            case .credentiallessUpsell:
                break
            }
            loginInterface = makeLoginInterface()
        case .signupStateChanged(.signupFinished):
            switch flow {
            case .normal:
                delegate?.userDidSignUp()
            case .credentiallessUpsell:
                // show top green banner
                showAccountCreatedBanner()
            }
            loginInterface = makeLoginInterface()
        case let .loginStateChanged(.dataIsAvailable(loginData)), let .signupStateChanged(.dataIsAvailable(loginData)):
            log.debug("Login or signup process in progress", category: .app)
            // Update the session id in the networking stack after login
            let uid = loginData.getCredential.UID
            networking.apiService.setSessionUID(uid: uid)
            if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.pushNotifications) {
                pushNotificationService.registerForRemoteNotifications(uid: uid)
            }
        }
    }

    private func showAccountCreatedBanner() {
        if let topmostPresentedViewController = windowService.topmostPresentedViewController {
            banner = PMBanner(
                message: Localizable.accountCreatedTitle,
                style: PMBannerNewStyle.success,
                dismissDuration: 3.0
            )
            banner?.show(at: .top, on: topmostPresentedViewController)
        }
    }

    private func show(initialError: String?, withOverlayViewController: UIViewController?) {
        #if DEBUG
            if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
                LoginExternalAccountNotSupportedSetup.start()
            }
        #endif

        let loginResultCompletion: (LoginAndSignupResult) -> Void = { [weak self] result in
            self?.processLoginResult(result: result, for: .normal)
        }
        let customization = LoginCustomizationOptions(
            username: nil,
            performBeforeFlow: finishFlow(),
            customErrorPresenter: self,
            initialError: initialError,
            helpDecorator: helpDecorator
        )
        let variant: WelcomeScreenVariant = if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.credentialLessDisabled, reloadValue: true) {
            .vpn(WelcomeScreenTexts(body: Localizable.welcomeBody))
        } else {
            .vpnV2(WelcomeScreenTexts(body: Localizable.welcomeBody))
        }
        let welcomeViewController = loginInterface.welcomeScreenForPresentingFlow(
            variant: variant,
            customization: customization,
            updateBlock: loginResultCompletion
        )
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
            return NetworkError(rawValue: underlyingError.code) ?? underlyingError
        }

        return underlyingError
    }
}

// MARK: LoginErrorPresenter

extension CoreLoginService: LoginErrorPresenter {
    func willPresentError(error: LoginError, from _: UIViewController) -> Bool {
        switch error {
        case .generic(_, _, CommonVpnError.subuserWithoutSessions):
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

    func willPresentError(error _: SignupError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: AvailabilityError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: SetUsernameError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: CreateAddressError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: CreateAddressKeysError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: StoreKitManagerErrors, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: ResponseError, from _: UIViewController) -> Bool {
        false
    }

    func willPresentError(error _: Error, from _: UIViewController) -> Bool {
        false
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
            #if DEBUG
                self.showAppDebugConfiguration()
            #else
                self.show(initialError: initialError, withOverlayViewController: overlayViewController)
            #endif
        }
    }

    func presentLoginFlow(over viewController: UIViewController, flow: LoginFlowType) {
        let setup = setupLoginInterface(flow: flow)
        loginInterface.presentLoginFlow(
            over: viewController,
            customization: setup.customization,
            updateBlock: setup.completion
        )
    }

    func presentSignUpFlow(over viewController: UIViewController, flow: LoginFlowType) {
        let setup = setupLoginInterface(flow: flow)
        loginInterface.presentSignupFlow(
            over: viewController,
            customization: setup.customization,
            updateBlock: setup.completion
        )
    }

    private func setupLoginInterface(flow: LoginFlowType) -> (
        completion: (LoginAndSignupResult) -> Void,
        customization: LoginCustomizationOptions
    ) {
        let loginResultCompletion: (LoginAndSignupResult) -> Void = { [weak self] result in
            self?.processLoginResult(result: result, for: flow)
        }
        var closeSignupFlowAlertConfirmation: CloseSignupFlowAlertConfirmation?
        if flow == .credentiallessUpsell {
            closeSignupFlowAlertConfirmation = .init(
                title: Localizable.createAccountIfCloseNoUpgrade,
                cancelButtonTitle: Localizable.createAccountCancelUpgrade,
                continueButtonTitle: Localizable.createAccountContinueCreating
            )
        }
        let customization = LoginCustomizationOptions(
            performBeforeFlow: finishFlow(),
            customErrorPresenter: self,
            helpDecorator: helpDecorator,
            closeSignupFlowAlertConfirmation: closeSignupFlowAlertConfirmation
        )

        loginInterface = makeLoginInterface(isCloseButtonAvailable: true)
        return (loginResultCompletion, customization)
    }

    #if DEBUG
        private func showAppDebugConfiguration() {
            let appDebugConfigurationView = EnvironmentSelectorMobileView { [weak self] in
                self?.show(initialError: nil, withOverlayViewController: nil)
            }

            let environmentsViewController = UIHostingController(rootView: appDebugConfigurationView)
            windowService.show(viewController: environmentsViewController)
        }
    #endif
}
