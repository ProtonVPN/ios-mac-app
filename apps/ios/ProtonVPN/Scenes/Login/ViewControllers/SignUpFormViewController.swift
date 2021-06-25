//
//  SignUpFormViewController.swift
//  ProtonVPN - Created on 11/09/2019.
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

import UIKit
import vpncore
import GSMessages

final class SignUpFormViewController: UIViewController {

    // Properties
    private var visibleConstraintConstant: CGFloat = 171
    private var wasShownBefore = false
    var viewModel: SignUpFormViewModel! {
        didSet {
            viewModel.showError = { [weak self] error in self?.showError(error) }
            viewModel.loadingStateChanged = { [weak self] loading in self?.showLoading(loading) }
        }
    }
    
    // Views
    @IBOutlet private weak var textFieldStackView: UIStackView!
    @IBOutlet private weak var mainButton: ProtonButton!
    @IBOutlet private weak var minVisibleConstraint: NSLayoutConstraint!
    @IBOutlet private weak var formHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var topPaddingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var termsAndConditionsTextView: UITextView!
    @IBOutlet private weak var footerStackView: UIStackView!
    @IBOutlet private weak var underLogoLabel: UILabel!
    @IBOutlet private weak var dismissButton: UIButton!

    private let emailField = ProtonTextField.textField(contentType: .email, placeholder: LocalizedString.enterEmailAddress, icon: "email", returnKeyType: .next)
    private let usernameField = ProtonTextField.textField(contentType: .username, placeholder: LocalizedString.username, icon: "username", returnKeyType: .next)
    private let password1Field = ProtonTextField.textField(contentType: .password, placeholder: LocalizedString.password, icon: "password", returnKeyType: .next)
    private let password2Field = ProtonTextField.textField(contentType: .password, placeholder: LocalizedString.passwordConfirm, icon: "password", returnKeyType: .join)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        underLogoLabel.isHidden = false
        if UIDevice.current.isSmallIphone {
            visibleConstraintConstant = 100
            footerStackView.spacing = 4
            underLogoLabel.isHidden = true
        } else if UIDevice.current.screenType == .iPhones_6_6s_7_8 {
            visibleConstraintConstant = 110
            footerStackView.spacing = 4
        } else if UIDevice.current.screenType == .iPhones_XR_11 || UIDevice.current.screenType == .iPhones_X_XS_11Pro || UIDevice.current.screenType == .iPhones_XSMax_11ProMax {
            topPaddingConstraint.constant = 50
        }
        minVisibleConstraint.constant = visibleConstraintConstant
        self.view.layoutIfNeeded()
        
        setupCloseButton()
        setupTextFields()
        setupMainButton()
        setupFooterSection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        if shouldShowCloseButton {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !wasShownBefore {
            emailField.becomeFirstResponder()
            wasShownBefore = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        view.endEditing(true)
        if shouldShowCloseButton {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }
    
    // MARK: UI
    
    private var shouldShowCloseButton: Bool {
        guard let navigationController = navigationController else {
            return true
        }
        return navigationController.children[0] == self
    }
    
    private func setupCloseButton() {
        dismissButton.imageView?.image = dismissButton.imageView?.image?.withRenderingMode(.alwaysTemplate)
        dismissButton.accessibilityIdentifier = "close"
        dismissButton.isHidden = !shouldShowCloseButton
    }
    
    private func setupTextFields() {
        textFieldStackView.removeArrangedSubview(mainButton)
        [emailField, usernameField, password1Field, password2Field].forEach { field in
            self.textFieldStackView.addArrangedSubview(field)
            field.leftAnchor.constraint(equalTo: self.textFieldStackView.leftAnchor).isActive = true
            field.rightAnchor.constraint(equalTo: self.textFieldStackView.rightAnchor).isActive = true
        }
        textFieldStackView.addArrangedSubview(mainButton)
        view.setNeedsLayout()
        
        emailField.returnPressed = { [weak self] _ in self?.usernameField.focus() }
        viewModel.observeTextField(textField: emailField, type: .recoveryEmail)

        usernameField.returnPressed = { [weak self] _ in self?.password1Field.focus() }
        viewModel.observeTextField(textField: usernameField, type: .username)

        password1Field.returnPressed = { [weak self] _ in self?.password2Field.focus() }
        viewModel.observeTextField(textField: password1Field, type: .password)

        password2Field.returnPressed = { [weak self] _ in
            self?.view.endEditing(true)
            self?.mainButtonTapped(self as Any)
        }
        viewModel.observeTextField(textField: password2Field, type: .passwordConfirmation)

        emailField.textChanged = { [weak self] textField in self?.viewModel.email = textField.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        usernameField.textChanged = { [weak self] textField in self?.viewModel.username = textField.text }
        password1Field.textChanged = { [weak self] textField in self?.viewModel.password1 = textField.text }
        password2Field.textChanged = { [weak self] textField in self?.viewModel.password2 = textField.text }
        
        emailField.textField.accessibilityIdentifier = "email"
        usernameField.textField.accessibilityIdentifier = "username"
        password1Field.textField.accessibilityIdentifier = "pass1"
        password2Field.textField.accessibilityIdentifier = "pass2"
        
        formHeightConstraint.constant = 88 * 4 + 50
        view.setNeedsLayout()
    }
    
    private func setupMainButton() {
        mainButton.setTitle(LocalizedString.createAccount, for: .normal)
        mainButton.accessibilityIdentifier = "mainButton"
        self.renderMainButton()
        viewModel.formDataChanged = { [weak self] in
            self?.renderMainButton()
        }
    }
    
    private func setupFooterSection() {
        let switchToLoginTitle = LocalizedString.alreadyHaveAccount.attributed(withColor: .protonUnavailableGrey(), fontSize: 14, alignment: .center)
        loginButton.setAttributedTitle(switchToLoginTitle, for: .normal)
        let attributedDisclaimer = NSMutableAttributedString(attributedString: LocalizedString.termsAndConditionsDisclaimer(LocalizedString.termsAndConditions, LocalizedString.privacyPolicy).attributed(withColor: .protonFontDark(), fontSize: 12))
        let fullRange = (attributedDisclaimer.string as NSString).range(of: attributedDisclaimer.string)
        let termsRange = (attributedDisclaimer.string as NSString).range(of: LocalizedString.termsAndConditions)
        let privacyRange = (attributedDisclaimer.string as NSString).range(of: LocalizedString.privacyPolicy)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3
        attributedDisclaimer.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        attributedDisclaimer.addAttribute(.link, value: CoreAppConstants.ProtonVpnLinks.termsAndConditions, range: termsRange)
        attributedDisclaimer.addAttribute(.link, value: CoreAppConstants.ProtonVpnLinks.privacyPolicy, range: privacyRange)
        attributedDisclaimer.addAttribute(.foregroundColor, value: UIColor.white, range: termsRange)
        termsAndConditionsTextView.attributedText = attributedDisclaimer
        
        let linkAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: UIColor.protonFontDark(),
            NSAttributedString.Key.underlineColor: UIColor.protonUnavailableGrey(),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        termsAndConditionsTextView.linkTextAttributes = linkAttributes
    }
    
    private func renderMainButton() {
        DispatchQueue.main.async {
            self.mainButton.isEnabled = self.viewModel.isEnoughData
        }
    }
    
    private func validateFormFields() -> Bool {
        var isValid = true
        if let emailError = viewModel.validateEmail() {
            emailField.state = .error(emailError.localizedDescription, emailError.identifier)
            isValid = false
        } else {
            emailField.state = .normal
        }
        if let usernameError = viewModel.validateUserName() {
            usernameField.state = .error(usernameError.localizedDescription, usernameError.identifier)
            isValid = false
        } else {
            usernameField.state = .normal
        }
        if let password1Error = viewModel.validatePassword1() {
            password1Field.state = .error(password1Error.localizedDescription, password1Error.identifier)
            isValid = false
        } else {
            password1Field.state = .normal
        }
        if let password2Error = viewModel.validatePassword2() {
            password2Field.state = .error(password2Error.localizedDescription, password2Error.identifier)
            isValid = false
        } else {
            password2Field.state = .normal
        }
        return isValid
    }
    
    private func showError(_ error: Error) {
        PMLog.ET(error.localizedDescription)
        self.showMessage(error.localizedDescription, type: GSMessageType.error, options: UIConstants.messageOptions)
    }
    
    private func showLoading(_ loading: Bool) {
        if loading {
            mainButton.showLoading()
            mainButton.isEnabled = false
        } else {
            mainButton.hideLoading()
            mainButton.isEnabled = true
        }
    }
    
    // MARK: Keyboard
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        changeConstraintBasedOnKeyboardChange(notification, constraint: minVisibleConstraint, maxConstraintConstant: visibleConstraintConstant)
    }
    
    // MARK: User actions
    
    @IBAction func backgroundTapped(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func mainButtonTapped(_ sender: Any) {
        guard validateFormFields() else {
            return
        }
        
        viewModel.startRegistration()
    }
    
    @IBAction func switchToLogin(_ sender: Any) {
        viewModel?.switchToLogin()
    }
    
    @IBAction private func closeButtonTapped(_ sender: Any) {
        viewModel.cancel()
    }
    
}
