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
        self.view.addSubview(view)
        view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        let topConstraint = view.topAnchor.constraint(equalTo: self.view.topAnchor)
        topConstraint.constant = 150
        topConstraint.isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        return view
    }()

    @IBOutlet private weak var logoImage: NSImageView!
    @IBOutlet private weak var warningLabel: PVPNTextField!
    @IBOutlet private weak var helpLink: PVPNHyperlinkTextField!
    
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
        let topConstraint = view.topAnchor.constraint(equalTo: self.view.topAnchor)
        topConstraint.constant = 150
        topConstraint.isActive = true
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
    
        logoImage.imageScaling = .scaleProportionallyUpOrDown
        setupLoadingView()
        setupOnboardingView()
        setupTwoFactorView()
        setupCallbacks()

        viewModel.updateAvailableDomains()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        viewModel.logInApperared()
    }
    
    // MARK: - Private functions
    private func setupLoadingView() {
        reachabilityCheckIndicator.set(tintColor: NSColor.protonGreen())
    }

    private func setupTwoFactorView() {
        twoFactorView.isHidden = true
        twoFactorView.delegate = self
    }
    
    private func setupOnboardingView() {
        onboardingView.isHidden = true
        
        setupWarningSection()
        setupUsernameSection()
        setupPasswordSection()
        setupSwitchSection()
        setupFooterSection()
    }
    
    private func setupWarningSection() {
        warningLabel.isHidden = true
        
        helpLink.title = LocalizedString.learnMore
        helpLink.isHidden = true
        helpLink.target = self
        helpLink.action = #selector(keychainHelpAction)
    }
    
    private func setupUsernameSection() {
        usernameTextField.textColor = .protonWhite()
        usernameTextField.font = .systemFont(ofSize: 14)
        usernameTextField.placeholderAttributedString = LocalizedString.username.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, alignment: .left)
        usernameTextField.usesSingleLineMode = true
        usernameTextField.tag = TextField.username.rawValue
        usernameTextField.delegate = self
        usernameTextField.focusDelegate = self
        
        usernameTextField.setAccessibilityIdentifier("UsernameTextField")
        
        usernameHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupPasswordSection() {
        passwordSecureTextField.textColor = .protonWhite()
        passwordSecureTextField.font = .systemFont(ofSize: 14)
        passwordSecureTextField.usesSingleLineMode = true
        passwordSecureTextField.isHidden = false
        passwordSecureTextField.tag = TextField.passwordSecure.rawValue
        passwordSecureTextField.delegate = self
        passwordSecureTextField.focusDelegate = self
        
        passwordTextField.textColor = .protonWhite()
        passwordTextField.font = .systemFont(ofSize: 14)
        passwordTextField.usesSingleLineMode = true
        passwordTextField.isHidden = true
        passwordTextField.tag = TextField.password.rawValue
        passwordTextField.delegate = self
        passwordTextField.focusDelegate = self
        
        passwordSecureTextField.setAccessibilityIdentifier("PasswordTextField")
        
        passwordSecureTextField.placeholderAttributedString = LocalizedString.password.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, alignment: .left)
        passwordTextField.placeholderAttributedString = LocalizedString.password.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, alignment: .left)
        
        passwordRevealButton.setButtonType(.toggle)
        passwordRevealButton.image = NSImage(named: NSImage.Name("eye-show"))
        passwordRevealButton.alternateImage = NSImage(named: NSImage.Name("eye-hide"))
        passwordRevealButton.imagePosition = .imageOnly
        passwordRevealButton.isBordered = false
        passwordRevealButton.target = self
        passwordRevealButton.action = #selector(togglePasswordField)
        passwordRevealButton.setAccessibilityLabel(LocalizedString.show)
        
        passwordHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupSwitchSection() {
        startOnBootLabel.attributedStringValue = LocalizedString.startOnBoot.attributed(withColor: .protonWhite(), fontSize: 14, alignment: .left)
        startOnBootButton.setAccessibilityLabel(LocalizedString.startOnBoot)
        
        startOnBootButton.drawsUnderOverlay = false
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
        if let description = description {
            warningLabel.attributedStringValue = description.attributed(withColor: .protonRed(), fontSize: 14)
            warningLabel.isHidden = false
        }

        _ = twoFactorView.becomeFirstResponder()
        onboardingView.isHidden = true
        twoFactorView.isHidden = false

        loadingView.animate(false)
    }
    
    private func presentLoadingScreen() {
        warningLabel.isHidden = true
        helpLink.isHidden = true
        onboardingView.isHidden = true
        twoFactorView.isHidden = true

        loadingView.animate(true)
    }
    
    private func handleLoginFailure(_ errorMessage: String?) {
        presentOnboardingScreen(withErrorDescription: errorMessage)
    }
    
    private func handleLoginFailureWithSupport(_ errorMessage: String?) {
        if viewModel.isTwoFactorStep {
            presentTwoFactorScreen(withErrorDescription: errorMessage)
        } else {
            presentOnboardingScreen(withErrorDescription: errorMessage)
        }
        helpLink.isHidden = false
    }
    
    private func presentOnboardingScreen(withErrorDescription description: String?) {
        if let description = description {
            warningLabel.attributedStringValue = description.attributed(withColor: .protonRed(), fontSize: 14)
            warningLabel.isHidden = false
        }

        _ = usernameTextField.becomeFirstResponder()
        onboardingView.isHidden = false
        twoFactorView.isHidden = true
        loadingView.animate(false)
    }
    
    @objc private func keychainHelpAction() {
        viewModel.keychainHelpAction()
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
    func didReceiveFocus(_ textField: NSTextField) {
        switch textField.tag {
        case TextField.username.rawValue:
            usernameHorizontalLine.fillColor = .protonGreen()
            passwordHorizontalLine.fillColor = .protonLightGrey()
        case TextField.password.rawValue, TextField.passwordSecure.rawValue:
            usernameHorizontalLine.fillColor = .protonLightGrey()
            passwordHorizontalLine.fillColor = .protonGreen()
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
