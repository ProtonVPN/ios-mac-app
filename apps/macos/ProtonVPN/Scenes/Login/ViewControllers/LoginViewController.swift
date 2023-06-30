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

import Cocoa
import vpncore
import Foundation
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
    
    // MARK: - Onboarding view
    @IBOutlet private weak var onboardingView: NSView!

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

    @IBOutlet private weak var logoImage: NSImageView!
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
    
    @IBOutlet private weak var usernameTextField: TextFieldWithFocus!
    @IBOutlet private weak var usernameHorizontalLine: NSBox!
    
    @IBOutlet private weak var passwordTextField: TextFieldWithFocus!
    @IBOutlet private weak var passwordSecureTextField: SecureTextFieldWithFocus!
    @IBOutlet private weak var passwordRevealButton: NSButton!
    @IBOutlet private weak var passwordHorizontalLine: NSBox!
    
    @IBOutlet private weak var startOnBootLabel: PVPNTextField!
    @IBOutlet private weak var startOnBootButton: SwitchButton!
    
    @IBOutlet private weak var loginButton: LoginButton!
    @IBOutlet weak var createAccountButton: InteractiveActionButton!
    @IBOutlet weak var needHelpButton: InteractiveActionButton!
    
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

    @IBOutlet private weak var reachabilityCheckIndicator: NSProgressIndicator!
    
    private var helpPopover: NSPopover?
    
    fileprivate var viewModel: LoginViewModel!
    fileprivate var secureTextEntry = true
    
    fileprivate var passwordEntry: String {
        return secureTextEntry ? passwordSecureTextField.stringValue : passwordTextField.stringValue
    }
    
    // MARK: - Public functions
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: LoginViewModel) {
        super.init(nibName: NSNib.Name("Login"), bundle: nil)
        self.viewModel = viewModel
    }
    
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
        
        viewModel.logInAppeared()
    }
    
    // MARK: - Private functions
    private func setupLoadingView() {
        loadingView.isHidden = true
        reachabilityCheckIndicator.set(tintColor: .color(.icon, .interactive))
    }

    private func setupTwoFactorView() {
        twoFactorView.isHidden = true
        twoFactorView.delegate = self
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
        usernameTextField.style(placeholder: LocalizedString.username)
        usernameTextField.usesSingleLineMode = true
        usernameTextField.tag = TextField.username.rawValue
        usernameTextField.delegate = self
        usernameTextField.focusDelegate = self
        usernameTextField.setAccessibilityIdentifier("UsernameTextField")
        
        usernameHorizontalLine.fillColor = .color(.border, .weak)
    }
    
    private func setupPasswordSection() {
        passwordSecureTextField.style(placeholder: LocalizedString.password)
        passwordSecureTextField.usesSingleLineMode = true
        passwordSecureTextField.isHidden = false
        passwordSecureTextField.tag = TextField.passwordSecure.rawValue
        passwordSecureTextField.delegate = self
        passwordSecureTextField.focusDelegate = self

        passwordTextField.style(placeholder: LocalizedString.password)
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
        passwordRevealButton.setAccessibilityLabel(LocalizedString.show)
        
        passwordHorizontalLine.fillColor = .color(.border, .weak)
    }
    
    private func setupSwitchSection() {
        startOnBootLabel.attributedStringValue = LocalizedString.startOnBoot.styled(alignment: .left)
        startOnBootButton.setAccessibilityLabel(LocalizedString.startOnBoot)
        
        startOnBootButton.drawsUnderOverlay = true
        startOnBootButton.maskColor = .cgColor(.background)
        startOnBootButton.buttonView?.tag = Switch.startOnBoot.rawValue
        startOnBootButton.setState(viewModel.startOnBoot ? .on : .off)
        startOnBootButton.delegate = self
    }
    
    private func setupFooterSection() {
        loginButton.isEnabled = false
        loginButton.target = self
        loginButton.action = #selector(loginButtonAction)
        
        createAccountButton.title = LocalizedString.createAccount
        createAccountButton.target = self
        createAccountButton.action = #selector(createAccountButtonAction)
        
        needHelpButton.title = LocalizedString.needHelp
        needHelpButton.target = self
        needHelpButton.action = #selector(needHelpButtonAction)
        
        loginButton.setAccessibilityIdentifier("LoginButton")
    }
    
    private func setupCallbacks() {
        viewModel.logInInProgress = { [weak self] in self?.presentLoadingScreen() }
        viewModel.logInFailure = { [weak self] errorMessage in self?.handleLoginFailure(errorMessage) }
        viewModel.logInFailureWithSupport = { [weak self] errorMessage in self?.handleLoginFailureWithSupport(errorMessage) }
        viewModel.checkInProgress = { [weak self] checkInProgress in
            if checkInProgress {
                self?.reachabilityCheckIndicator.startAnimation(nil)
            } else {
                self?.reachabilityCheckIndicator.stopAnimation(nil)
            }
        }
        viewModel.twoFactorRequired = { [weak self] in self?.presentTwoFactorScreen(withErrorDescription: nil) }
    }
    
    private func attemptLogin() {
        viewModel.logIn(username: usernameTextField.stringValue, password: passwordEntry)
    }

    private func presentTwoFactorScreen(withErrorDescription description: String?) {
        twoFactorView.warningMessage = description

        _ = twoFactorView.becomeFirstResponder()
        onboardingView.isHidden = true
        twoFactorView.isHidden = false
        logoImage.isHidden = false

        loadingView.animate(false)
    }
    
    private func presentLoadingScreen() {
        warningView.isHidden = true
        warningView.showSupport = false
        onboardingView.isHidden = true
        logoImage.isHidden = true
        twoFactorView.isHidden = true

        loadingView.isHidden = false
        loadingView.animate(true)
    }
    
    private func handleLoginFailure(_ errorMessage: String?) {
        if viewModel.isTwoFactorStep {
            presentTwoFactorScreen(withErrorDescription: errorMessage)
        } else {
            presentOnboardingScreen(withErrorDescription: errorMessage)
        }
    }
    
    private func handleLoginFailureWithSupport(_ errorMessage: String?) {
        handleLoginFailure(errorMessage)
        warningView.showSupport = true
    }
    
    private func presentOnboardingScreen(withErrorDescription description: String?) {
        warningView.message = description

        _ = usernameTextField.becomeFirstResponder()
        onboardingView.isHidden = false
        twoFactorView.isHidden = true
        loadingView.isHidden = true
        logoImage.isHidden = false
        loadingView.animate(false)
    }
    
    @objc private func togglePasswordField() {
        if secureTextEntry {
            passwordTextField.stringValue = passwordSecureTextField.stringValue
        } else {
            passwordSecureTextField.stringValue = passwordTextField.stringValue
        }
        
        secureTextEntry = !secureTextEntry
        passwordTextField.isHidden = secureTextEntry
        passwordSecureTextField.isHidden = !secureTextEntry
        passwordRevealButton.setAccessibilityValue(secureTextEntry ? LocalizedString.hide : LocalizedString.show)
    }
    
    @objc private func loginButtonAction() {
        attemptLogin()
    }
    
    @objc private func createAccountButtonAction() {
        viewModel.createAccountAction()
    }
    
    @objc private func needHelpButtonAction() {
        guard helpPopover == nil else { return }
        
        helpPopover = NSPopover()
        helpPopover!.contentViewController = HelpPopoverViewController(viewModel: viewModel.helpPopoverViewModel)
        helpPopover!.appearance = NSAppearance(named: .vibrantDark)
        helpPopover!.behavior = .transient
        helpPopover!.show(relativeTo: needHelpButton.bounds, of: needHelpButton, preferredEdge: .maxX)
        helpPopover!.delegate = self
    }
}

extension LoginViewController: WarningViewDelegate {
    func keychainHelpAction() {
        viewModel.keychainHelpAction()
    }
}

extension LoginViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        loginButton.isEnabled = !usernameTextField.stringValue.isEmpty && !passwordEntry.isEmpty
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {

        if commandSelector == #selector(NSResponder.insertNewline(_:)) && loginButton.isEnabled {
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
    func popoverDidClose(_ notification: Notification) {
        helpPopover = nil
    }
}
