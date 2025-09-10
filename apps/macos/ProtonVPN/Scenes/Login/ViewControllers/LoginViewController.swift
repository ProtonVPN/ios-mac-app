//
//  LoginViewController.swift
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

import AuthenticationServices
import Cocoa
import Foundation
import SwiftUI

import ProtonCoreFeatureFlags
import ProtonCoreLoginUI
import ProtonCoreObservability
import ProtonCoreServices

import LegacyCommon

import Settings_macOS

import Ergonomics
import Strings
import Theme

final class LoginViewController: NSViewController {
    fileprivate enum TextField: Int {
        case username
        case password
        case passwordSecure
    }

    fileprivate enum Switch: Int {
        case startOnBoot
    }

    fileprivate enum SigninVariant {
        case protonSignin
        case ssoSignin
    }

    // MARK: - Onboarding view

    @IBOutlet private var onboardingView: NSView!

    // MARK: - Two factor view

    private lazy var twoFactorView: TwoFactorView = {
        var nibObjects: NSArray?
        guard Bundle.main.loadNibNamed("TwoFactorView", owner: nil, topLevelObjects: &nibObjects),
              let view = nibObjects?.first(where: { $0 is TwoFactorView }) as? TwoFactorView else {
            fatalError()
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.logoImage.bottomAnchor, constant: 48).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        return view
    }()

    private lazy var anyTwoFactorContainerView: AnyTwoFactorView = {
        let view = AnyTwoFactorView(viewModel: .init(loginViewModel: self.viewModel, twoFactorDelegate: self))
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.logoImage.bottomAnchor, constant: 48).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        return view
    }()

    #if DEBUG
        private lazy var environmentSelectionView: NSHostingView<EnvironmentSelectorDesktopView> = {
            let environmentsView = EnvironmentSelectorDesktopView { [weak self] in
                guard let self else { return }

                _ = environmentSelectionView.resignFirstResponder()
                environmentSelectionView.removeFromSuperview()

                onboardingView.becomeFirstResponder()

                presentOnboardingScreen(withErrorDescription: nil)
            }

            let hostingView = NSHostingView(rootView: environmentsView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            return hostingView
        }()
    #endif

    @IBOutlet private var logoImage: NSImageView!
    private lazy var warningView: WarningView = {
        var nibObjects: NSArray?
        guard Bundle.main.loadNibNamed("WarningView", owner: nil, topLevelObjects: &nibObjects),
              let view = nibObjects?.first(where: { $0 is WarningView }) as? WarningView else {
            fatalError()
        }
        view.helpDelegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        view.leadingAnchor.constraint(equalTo: startOnBootLabel.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: startOnBootButton.trailingAnchor).isActive = true
        let topConstraint = view.topAnchor.constraint(equalTo: startOnBootLabel.bottomAnchor)
        topConstraint.constant = 42
        topConstraint.isActive = true
        view.bottomAnchor.constraint(lessThanOrEqualTo: loginButton.topAnchor).isActive = true
        return view
    }()

    @IBOutlet private var usernameTextField: TextFieldWithFocus!
    @IBOutlet private var usernameHorizontalLine: NSBox!

    @IBOutlet private var passwordTextField: TextFieldWithFocus!
    @IBOutlet private var passwordSecureTextField: SecureTextFieldWithFocus!
    @IBOutlet private var passwordRevealButton: NSButton!
    @IBOutlet private var passwordHorizontalLine: NSBox!

    @IBOutlet private var startOnBootLabel: PVPNTextField!
    @IBOutlet private var startOnBootButton: SwitchButton!

    @IBOutlet private var loginButton: LoginButton!
    @IBOutlet private var loginButtonToSSOButtonVerticalOffset: NSLayoutConstraint!
    @IBOutlet private var signInWithSSO: InteractiveActionButton!
    @IBOutlet var createAccountButton: InteractiveActionButton!
    @IBOutlet var needHelpButton: InteractiveActionButton!

    #if REDESIGN
        var coordinator: LoginViewControllerRepresentable.Coordinator?
    #endif

    // MARK: - Loading view

    private lazy var loadingView: LoadingView = {
        var nibObjects: NSArray?
        guard Bundle.main.loadNibNamed("LoadingView", owner: nil, topLevelObjects: &nibObjects),
              let view = nibObjects?.first(where: { $0 is LoadingView }) as? LoadingView else {
            fatalError()
        }
        self.view.addSubview(view)
        view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        return view
    }()

    @IBOutlet private var reachabilityCheckIndicator: NSProgressIndicator!

    private var helpPopover: NSPopover?

    fileprivate var viewModel: LoginViewModel!
    fileprivate var secureTextEntry = true
    fileprivate var signInVariant: SigninVariant = .protonSignin

    fileprivate var passwordEntry: String {
        secureTextEntry ? passwordSecureTextField.stringValue : passwordTextField.stringValue
    }

    // MARK: - Public functions

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    #if REDESIGN
        required init(viewModel: LoginViewModel, coordinator: LoginViewControllerRepresentable.Coordinator? = nil) {
            self.coordinator = coordinator
            super.init(nibName: NSNib.Name("Login"), bundle: nil)
            self.viewModel = viewModel
        }
    #else
        required init(viewModel: LoginViewModel) {
            super.init(nibName: NSNib.Name("Login"), bundle: nil)
            self.viewModel = viewModel
        }
    #endif
    deinit {
        loadingView.animate(false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        logoImage.image = Theme.Asset.vpnWordmarkAlwaysDark.image
        logoImage.imageScaling = .scaleProportionallyUpOrDown
        setupOnboardingView()
        setupTwoFactorView()
        setupCallbacks()

        viewModel.updateAvailableDomains()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        Task { @MainActor in
            await viewModel.logInAppeared()
        }
    }

    // MARK: - Private functions

    private func setupLoadingView() {
        loadingView.isHidden = true
        reachabilityCheckIndicator.set(tintColor: .color(.icon, .interactive))
    }

    private func setupTwoFactorView() {
        twoFactorView.isHidden = true
        twoFactorView.delegate = self

        anyTwoFactorContainerView.isHidden = true
    }

    private func setupOnboardingView() {
        onboardingView.isHidden = true
        logoImage.isHidden = true

        setupUsernameSection()
        setupPasswordSection()
        setupSwitchSection()
        setupFooterSection()
    }

    private func setupUsernameSection() {
        usernameTextField.style(placeholder: Localizable.username)
        usernameTextField.usesSingleLineMode = true
        usernameTextField.tag = TextField.username.rawValue
        usernameTextField.delegate = self
        usernameTextField.focusDelegate = self

        usernameTextField.setAccessibilityIdentifier("UsernameTextField")

        usernameHorizontalLine.fillColor = .color(.border, .weak)
    }

    private func setupPasswordSection() {
        passwordSecureTextField.style(placeholder: Localizable.password)
        passwordSecureTextField.usesSingleLineMode = true
        passwordSecureTextField.isHidden = false
        passwordSecureTextField.tag = TextField.passwordSecure.rawValue
        passwordSecureTextField.delegate = self
        passwordSecureTextField.focusDelegate = self

        passwordTextField.style(placeholder: Localizable.password)
        passwordTextField.usesSingleLineMode = true
        passwordTextField.isHidden = true
        passwordTextField.tag = TextField.password.rawValue
        passwordTextField.delegate = self
        passwordTextField.focusDelegate = self

        passwordSecureTextField.setAccessibilityIdentifier("PasswordTextField")

        passwordRevealButton.setButtonType(.toggle)
        passwordRevealButton.image = AppTheme.Icon.eye
        passwordRevealButton.alternateImage = AppTheme.Icon.eyeSlash
        passwordRevealButton.contentTintColor = .color(.icon, .interactive)
        passwordRevealButton.imagePosition = .imageOnly
        passwordRevealButton.isBordered = false
        passwordRevealButton.target = self
        passwordRevealButton.action = #selector(togglePasswordField)
        passwordRevealButton.setAccessibilityLabel(Localizable.show)

        passwordHorizontalLine.fillColor = .color(.border, .weak)
    }

    private func setupSwitchSection() {
        startOnBootLabel.attributedStringValue = Localizable.startOnBoot.styled(alignment: .left)
        startOnBootButton.setAccessibilityLabel(Localizable.startOnBoot)

        startOnBootButton.drawsUnderOverlay = true
        DarkAppearance {
            startOnBootButton.maskColor = .cgColor(.background)
        }
        startOnBootButton.buttonView?.tag = Switch.startOnBoot.rawValue
        startOnBootButton.setState(viewModel.startOnBoot ? .on : .off)
        startOnBootButton.delegate = self
    }

    private func setupFooterSection() {
        loginButton.isEnabled = false
        loginButton.target = self
        loginButton.action = #selector(loginButtonAction)

        signInWithSSO.isHidden = false
        loginButtonToSSOButtonVerticalOffset.isActive = true
        signInWithSSO.title = LUITranslation.sign_in_with_sso_button.l10n
        signInWithSSO.target = self
        signInWithSSO.action = #selector(signInWithSSOButtonAction)

        createAccountButton.title = Localizable.createAccount
        createAccountButton.target = self
        createAccountButton.action = #selector(createAccountButtonAction)

        needHelpButton.title = Localizable.needHelp
        needHelpButton.target = self
        needHelpButton.action = #selector(needHelpButtonAction)

        loginButton.setAccessibilityIdentifier("LoginButton")
    }

    private func setupCallbacks() {
        viewModel.logInInProgress = { [weak self] in self?.presentLoadingScreen() }
        viewModel.logInFailure = { [weak self] errorMessage, errorCode in self?.handleLoginFailure(errorMessage, errorCode) }
        viewModel.logInFailureWithSupport = { [weak self] errorMessage in self?.handleLoginFailureWithSupport(errorMessage) }
        viewModel.checkInProgress = { [weak self] checkInProgress in
            if checkInProgress {
                self?.reachabilityCheckIndicator.startAnimation(nil)
            } else {
                self?.reachabilityCheckIndicator.stopAnimation(nil)
            }
        }
        viewModel.twoFactorRequired = { [weak self] authOptions in
            guard let viewModel = self?.anyTwoFactorContainerView.viewModel else {
                assertionFailure()
                return
            }
            viewModel.authenticationOptions = authOptions
            self?.presentTwoFactorScreen(twoFactorViewModel: viewModel, withErrorDescription: nil)
        }
        viewModel.ssoChallengeReceived = { [weak self] request in
            DispatchQueue.main.async { [weak self] in
                self?.showSSOWebView(request: request)
            }
        }
    }

    private func attemptLogin() {
        switch signInVariant {
        case .protonSignin:
            viewModel.logIn(username: usernameTextField.stringValue, password: passwordEntry)
        case .ssoSignin:
            viewModel.logInWithSSO(username: usernameTextField.stringValue)
        }
    }

    #if DEBUG
        private func presentEnvironmentSelectionScreen() {
            onboardingView.isHidden = true
            logoImage.isHidden = true
            twoFactorView.isHidden = true
            environmentSelectionView.isHidden = false
            loadingView.animate(false)

            view.addSubview(environmentSelectionView)
            environmentSelectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            environmentSelectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            environmentSelectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            environmentSelectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

            _ = environmentSelectionView.becomeFirstResponder()
        }
    #endif

    private func presentTwoFactorScreen(twoFactorViewModel _: AnyTwoFactorViewModel, withErrorDescription description: String?) {
        switch viewModel.twoFactorViewKind {
        case .none:
            assertionFailure("This method shouldn't be called with this TwoFactorViewKind value")
            fallthrough
        case .askTOTP:
            twoFactorView.warningMessage = description

            onboardingView.isHidden = true
            twoFactorView.isHidden = false
            logoImage.isHidden = false

            _ = twoFactorView.becomeFirstResponder()

            loadingView.animate(false)
        case .askAny2FA:
            // twoFactorView.warningMessage = description

            onboardingView.isHidden = true
            anyTwoFactorContainerView.isHidden = false
            logoImage.isHidden = false

            _ = twoFactorView.becomeFirstResponder()

            loadingView.animate(false)
        }
    }

    private func showSSOWebView(request: URLRequest) {
        guard let authURL = request.url else { return }
        startWebAuthenticationSession(authURL)
    }

    private func presentLoadingScreen() {
        warningView.isHidden = true
        warningView.showSupport = false
        onboardingView.isHidden = true
        logoImage.isHidden = true
        twoFactorView.isHidden = true
        anyTwoFactorContainerView.isHidden = true

        loadingView.isHidden = false
        loadingView.animate(true)
    }

    private func handleLoginFailure(_ errorMessage: String?, _ errorCode: Int? = nil) {
        if viewModel.twoFactorViewKind.shouldShowTwoFactorScreen, let twoFactorViewModel = viewModel.twoFactorViewModel {
            presentTwoFactorScreen(twoFactorViewModel: twoFactorViewModel, withErrorDescription: errorMessage)
        } else if let errorCode, errorCode == ProtonCoreServices.APIErrorCode.switchToSSOError {
            signInWithSSOButtonAction()
            presentOnboardingScreen(withErrorDescription: errorMessage, warningType: .info)
        } else {
            #if DEBUG
                guard let errorMessage, !CommandLine.arguments.contains("-SkipEnvironmentSelection") else {
                    // If we're on DEBUG or STAGING, present environment selection screen before proceeding to login.
                    presentEnvironmentSelectionScreen()
                    return
                }
            #endif
            presentOnboardingScreen(withErrorDescription: errorMessage)
        }
    }

    private func handleLoginFailureWithSupport(_ errorMessage: String?) {
        handleLoginFailure(errorMessage)
        warningView.showSupport = true
    }

    private func presentOnboardingScreen(withErrorDescription description: String?, warningType: WarningType = .error) {
        warningView.setMessage(description, warningType: warningType)

        onboardingView.isHidden = false
        twoFactorView.isHidden = true
        loadingView.isHidden = true

        #if DEBUG
            // This occludes the username text field, which upsets UI tests. Since we don't need it anymore, remove it from
            // the current view.
            environmentSelectionView.removeFromSuperview()
        #endif

        _ = usernameTextField.becomeFirstResponder()

        logoImage.isHidden = false
        loadingView.animate(false)
    }

    @objc
    private func togglePasswordField() {
        if secureTextEntry {
            passwordTextField.stringValue = passwordSecureTextField.stringValue
        } else {
            passwordSecureTextField.stringValue = passwordTextField.stringValue
        }

        secureTextEntry = !secureTextEntry
        passwordTextField.isHidden = secureTextEntry
        passwordSecureTextField.isHidden = !secureTextEntry
        passwordRevealButton.setAccessibilityValue(secureTextEntry ? Localizable.hide : Localizable.show)
    }

    @objc
    private func loginButtonAction() {
        attemptLogin()
    }

    @objc
    private func signInWithSSOButtonAction() {
        switch signInVariant {
        case .protonSignin:
            signInVariant = .ssoSignin
            usernameTextField.style(placeholder: LUITranslation.email_field_title.l10n)
            loginButton.displayTitle = LUITranslation.sign_in_with_sso_button.l10n
            signInWithSSO.title = LUITranslation.sign_in_button_with_password.l10n
            createAccountButton.isHidden = true
            passwordTextField.isHidden = true
            passwordSecureTextField.isHidden = true
            passwordRevealButton.isHidden = true
            passwordHorizontalLine.isHidden = true
        case .ssoSignin:
            signInVariant = .protonSignin
            usernameTextField.style(placeholder: LUITranslation.username_title.l10n)
            loginButton.displayTitle = LUITranslation._core_sign_in_screen_title.l10n
            signInWithSSO.title = LUITranslation.sign_in_with_sso_button.l10n
            createAccountButton.isHidden = false
            passwordTextField.isHidden = secureTextEntry
            passwordSecureTextField.isHidden = !secureTextEntry
            passwordRevealButton.isHidden = false
            passwordHorizontalLine.isHidden = false
        }
        loginButton.needsDisplay = true
        loginButton.displayIfNeeded()
        warningView.isHidden = true
        enableLoginButtonBasedOnTextFieldsState()
    }

    @objc
    private func createAccountButtonAction() {
        viewModel.createAccountAction()
    }

    @objc
    private func needHelpButtonAction() {
        guard helpPopover == nil else { return }

        helpPopover = NSPopover()
        helpPopover!.contentViewController = HelpPopoverViewController(viewModel: viewModel.helpPopoverViewModel)
        helpPopover!.appearance = NSAppearance(named: .darkAqua)
        helpPopover!.behavior = .transient
        helpPopover!.show(relativeTo: needHelpButton.bounds, of: needHelpButton, preferredEdge: .maxX)
        helpPopover!.delegate = self
    }

    // MARK: - SSO

    private func startWebAuthenticationSession(_ authURL: URL) {
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "protonvpn") { callbackURL, error in
            guard error == nil, let callbackURL else {
                DispatchQueue.main.async { [weak self] in
                    ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .failed))

                    if let error {
                        log.error("SSO auth failed with error: \(error)", category: .core)
                    } else {
                        log.error("SSO auth failed: missing callbackURL", category: .core)
                    }

                    self?.presentOnboardingScreen(withErrorDescription: Localizable.ssoLoginFailure)
                }
                return
            }

            let ssoResponseTokenFound = self.identifyAndProcessSSOResponseToken(from: callbackURL)
            if !ssoResponseTokenFound {
                ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .failed))

                DispatchQueue.main.async { [weak self] in
                    log.error(
                        "SSO auth failed: missing token in SSO response",
                        category: .core,
                        metadata: ["url": "\(callbackURL)"]
                    )

                    self?.presentOnboardingScreen(withErrorDescription: Localizable.ssoLoginFailure)
                }
            } else {
                ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .successful))
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        session.start()
    }

    private func identifyAndProcessSSOResponseToken(from url: URL?) -> Bool {
        viewModel.identifyAndProcessSSOResponseToken(from: url, username: usernameTextField.stringValue)
    }
}

extension LoginViewController: WarningViewDelegate {
    func keychainHelpAction() {
        viewModel.keychainHelpAction()
    }
}

extension LoginViewController: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        enableLoginButtonBasedOnTextFieldsState()
    }

    fileprivate func enableLoginButtonBasedOnTextFieldsState() {
        switch signInVariant {
        case .protonSignin:
            loginButton.isEnabled = !usernameTextField.stringValue.isEmpty && !passwordEntry.isEmpty
        case .ssoSignin:
            loginButton.isEnabled = !usernameTextField.stringValue.isEmpty
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)), loginButton.isEnabled {
            attemptLogin()
            return true
        }

        return false
    }
}

extension LoginViewController: TwoFactorDelegate {
    func twoFactorButtonAction(code: String) {
        viewModel.provide2FACode(code: code)
    }

    func backAction() {
        presentOnboardingScreen(withErrorDescription: nil)
        viewModel.cancelTwoFactor()
    }
}

extension LoginViewController: TextFieldFocusDelegate {
    var shouldBecomeFirstResponder: Bool { true }

    func willReceiveFocus(_ textField: NSTextField) {
        switch textField.tag {
        case TextField.username.rawValue:
            usernameHorizontalLine.fillColor = .color(.border, [.interactive, .active])
            passwordHorizontalLine.fillColor = .color(.border, .weak)
        case TextField.password.rawValue, TextField.passwordSecure.rawValue:
            usernameHorizontalLine.fillColor = .color(.border, .weak)
            passwordHorizontalLine.fillColor = .color(.border, [.interactive, .active])
        default:
            break
        }
    }
}

extension LoginViewController: SwitchButtonDelegate {
    func switchButtonClicked(_ button: NSButton) {
        switch button.tag {
        case Switch.startOnBoot.rawValue:
            viewModel.startOnBoot(enabled: startOnBootButton.currentButtonState == .on)
        default:
            break
        }
    }
}

extension LoginViewController: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        helpPopover = nil
    }
}

extension LoginViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window!
    }
}
