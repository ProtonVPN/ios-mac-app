//
//  LoginViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import GSMessages
import UIKit
import vpncore

class LoginViewController: UIViewController {
    
    fileprivate enum TextField: Int {
        case username
        case password
    }
    
    private let footerConstraintConstant: CGFloat = 30
    private let fieldFontSize: CGFloat = 18
    
    private var shown = false
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var underLogoLabel: UILabel!
    
    @IBOutlet weak var textFieldStackView: UIStackView!
    
    @IBOutlet weak var usernameWrapperView: UIView!
    @IBOutlet weak var usernameIcon: UIImageView!
    @IBOutlet weak var usernameField: UITextField!
    
    @IBOutlet weak var passwordWrapperView: UIView!
    @IBOutlet weak var passwordIcon: UIImageView!
    @IBOutlet weak var securePasswordField: UITextField!
    @IBOutlet weak var unsecuredPasswordField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    
    @IBOutlet weak var loginButton: ProtonButton!
    
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var forgotSignupSeparator: UIView!
    @IBOutlet weak var signupButton: UIButton!
    
    @IBOutlet weak var footerStackView: UIStackView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    var viewModel: LoginViewModel? {
        didSet {
            viewModel?.delegate = self
        }
    }
    private var alertService: AlertService! {
        return viewModel?.alertService
    }
    
    weak var delegate: TabBarViewModelModelDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        view.backgroundColor = .protonBlack()
        
        setupHeaderSection()
        setupUsernameSection()
        setupPasswordSection()
        setupFooterSection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !shown {
            if usernameField.text == nil || usernameField.text!.isEmpty {
                usernameField.becomeFirstResponder()
            }
            shown = true
        }
        
        if let errorMessage = viewModel?.openingError {
            self.showMessage(errorMessage, type: GSMessageType.warning, options: UIConstants.messageOptions)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        resignAllTextFields()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        guard let info = notification.userInfo,
              let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
              let animationCurveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        // FUTUREFIX: iPad split keyboard
//        let endFrameInWindow: CGRect = view.convert(endFrame, from: view.window)
        
        let animationOptions = UIView.AnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | animationCurveRaw << 16)
        
        if endFrame.minY >= UIScreen.main.bounds.maxY { // Keyboard disappearing
            self.bottomConstraint.constant = self.footerConstraintConstant
        } else {
            let coef: CGFloat = UIDevice.current.screenType == .iPhones_5_5s_5c_SE ? 15.0 : 0.0
            self.bottomConstraint.constant = endFrame.size.height - self.footerStackView.frame.size.height - self.footerConstraintConstant + self.textFieldStackView.spacing - coef
        }

        UIView.animate(withDuration: duration, delay: 0, options: animationOptions, animations: { [unowned self] in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    // MARK: - Private functions
    private func setupHeaderSection() {
        dismissButton.imageView?.image = dismissButton.imageView?.image?.withRenderingMode(.alwaysTemplate)
        dismissButton.accessibilityIdentifier = "close"
        if let viewModel = viewModel {
            dismissButton.isHidden = !viewModel.dismissible
        }
    }
    
    private func setupUsernameSection() {
        usernameWrapperView.backgroundColor = .clear
        
        usernameIcon.image = usernameIcon.image?.withRenderingMode(.alwaysTemplate)
        usernameIcon.tintColor = .protonUnavailableGrey()
        
        usernameField.delegate = self
        usernameField.tag = TextField.username.rawValue
        
        usernameField.attributedPlaceholder = LocalizedString.username.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        usernameField.textColor = .protonWhite()
        usernameField.minimumFontSize = fieldFontSize
        usernameField.text = viewModel?.username
    }
    
    private func setupPasswordSection() {
        passwordWrapperView.backgroundColor = .clear
        
        passwordIcon.image = passwordIcon.image?.withRenderingMode(.alwaysTemplate)
        passwordIcon.tintColor = .protonUnavailableGrey()
        
        securePasswordField.delegate = self
        securePasswordField.tag = TextField.password.rawValue
        
        securePasswordField.attributedPlaceholder = LocalizedString.password.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        securePasswordField.textColor = .protonWhite()
        securePasswordField.minimumFontSize = fieldFontSize
        
        unsecuredPasswordField.delegate = self
        unsecuredPasswordField.tag = TextField.password.rawValue
        
        unsecuredPasswordField.attributedPlaceholder = LocalizedString.password.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        unsecuredPasswordField.textColor = .protonWhite()
        unsecuredPasswordField.minimumFontSize = fieldFontSize
        
        showPassword(false)
    }
    
    private func setupFooterSection() {
        loginButton.isEnabled = false
        loginButton.accessibilityIdentifier = "login_button"
        loginButton.setTitle(LocalizedString.logIn, for: .normal)
        
        let forgotPasswordTitle = LocalizedString.forgotPassword.attributed(withColor: .protonUnavailableGrey(), fontSize: 14, alignment: .center)
        forgotPasswordButton.setAttributedTitle(forgotPasswordTitle, for: .normal)
        let signUpTitle = LocalizedString.signUp.attributed(withColor: .protonUnavailableGrey(), fontSize: 14, alignment: .center)
        signupButton.setAttributedTitle(signUpTitle, for: .normal)
    }
    
    private func showPassword(_ show: Bool) {
        securePasswordField.isHidden = show
        unsecuredPasswordField.isHidden = !show
        
        showPasswordButton.setAttributedTitle((show ? LocalizedString.hide : LocalizedString.show).attributed(withColor: .protonFontDark(), fontSize: 14), for: .normal)
        
        if show {
            unsecuredPasswordField.text = securePasswordField.text
            if securePasswordField.isEditing {
                unsecuredPasswordField.becomeFirstResponder()
            }
        } else {
            securePasswordField.text = unsecuredPasswordField.text
            if unsecuredPasswordField.isEditing {
                securePasswordField.becomeFirstResponder()
            }
        }
    }
    
    private func resignAllTextFields() {
        usernameField.resignFirstResponder()
        securePasswordField.resignFirstResponder()
        unsecuredPasswordField.resignFirstResponder()
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction private func usernameWrapperTapped(_ sender: Any) {
        usernameField.becomeFirstResponder()
    }
    
    @IBAction private func passwordWrapperTapped(_ sender: Any) {
        if securePasswordField.isHidden {
            unsecuredPasswordField.becomeFirstResponder()
        } else {
            securePasswordField.becomeFirstResponder()
        }
    }
    
    @IBAction private func backgroundTapped(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction private func showPasswordTapped(_ sender: Any) {
        showPassword(unsecuredPasswordField.isHidden)
    }
    
    @IBAction private func loginTapped(_ sender: Any) {
        guard let username = usernameField.text,
            let password = securePasswordField.isHidden ?
                unsecuredPasswordField.text :
                securePasswordField.text else { return }
        viewModel?.logIn(username: username, password: password)
        
        resignAllTextFields()
        loginButton.isEnabled = false
        loginButton.showLoading()
    }
    
    @IBAction func forgotPassword(_ sender: Any) {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.resetPassword)
    }
    
    @IBAction func signUp(_ sender: Any) {
        viewModel?.signUpTapped()
    }
}

extension LoginViewController: LoginViewModelDelegate {
    
    func showError(_ error: Error) {
        PMLog.ET(error.localizedDescription)
        loginButton.hideLoading()
        
        if error.isTlsError || error.isNetworkError {
            alertService.push(alert: UnreachableNetworkAlert(error: error, troubleshoot: { [weak self] in
                self?.alertService.push(alert: ConnectionTroubleshootingAlert())
            }))
            
        } else if case ProtonVpnError.subuserWithoutSessions = error {
            let controller = SubuserAlertViewController()
            controller.safariServiceFactory = viewModel?.safariServiceFactory
            self.present(controller, animated: true, completion: {})
            
        } else {
            alertService.push(alert: ErrorNotificationAlert(error: error))
            usernameIcon.tintColor = .protonRed()
            passwordIcon.tintColor = .protonRed()
        }
        
        loginButton.isEnabled = !((error as NSError).code == ApiErrorCode.wrongLoginCredentials)
    }
    
    func dismissLogin() {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        
        if textField == usernameField {
            loginButton.isEnabled = !currentText.isEmpty &&
                                    !(securePasswordField.isHidden ? unsecuredPasswordField.text?.isEmpty ?? true :
                                                                     securePasswordField.text?.isEmpty ?? true)
        } else {
            loginButton.isEnabled = !currentText.isEmpty &&
                                    !(usernameField.text?.isEmpty ?? true)
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameField {
            securePasswordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginTapped(textField)
        }
        
        return true
    }
}
