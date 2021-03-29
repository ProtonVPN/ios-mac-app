//
//  SignUpViewController.swift
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

class VerificationEmailViewController: UIViewController {
    
    // MARK: Properties
    private let visibleConstraintConstant: CGFloat = 171
    private let fieldFontSize: CGFloat = 18
    
    private var shown = false
        
    @IBOutlet weak var textFieldStackView: UIStackView!
    @IBOutlet weak var underLogoLabel: UILabel!
    
    @IBOutlet weak var emailWrapperView: UIView!
    @IBOutlet weak var emailIcon: UIImageView!
    @IBOutlet weak var emailField: UITextField!
    
    @IBOutlet weak var getVerificationEmailButton: ProtonButton!
    @IBOutlet weak var minVisibleConstraint: NSLayoutConstraint!
        
    var viewModel: VerificationEmailViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .protonPlansGrey()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        
        setupEmailTextField()
        setupVerificationButton()
        
        emailField.text = viewModel?.getEmail()
        getVerificationEmailButton.isEnabled = !emailField.text.isEmpty
        viewModel?.verificationButtonEnabled = { [weak self] enabled in
            self?.enableVerificationButton(enabled)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !shown {
            emailField.becomeFirstResponder()
            shown = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        emailField.resignFirstResponder()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        getVerificationEmailButton.hideLoading()
        getVerificationEmailButton.isEnabled = !(emailField.text ?? "").isEmpty
    }
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        changeConstraintBasedOnKeyboardChange(notification, constraint: minVisibleConstraint, maxConstraintConstant: visibleConstraintConstant)
    }
        
    private func setupEmailTextField() {
        emailWrapperView.backgroundColor = view.backgroundColor
        
        emailIcon.image = emailIcon.image?.withRenderingMode(.alwaysTemplate)
        emailIcon.tintColor = .protonUnavailableGrey()
        
        emailField.delegate = self
        emailField.attributedPlaceholder = LocalizedString.enterEmailAddress.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        emailField.textColor = .protonWhite()
        emailField.minimumFontSize = fieldFontSize
    }
    
    private func setupVerificationButton() {
        getVerificationEmailButton.isEnabled = false
        getVerificationEmailButton.setTitle(LocalizedString.getVerificationEmail, for: .normal)
    }
        
    private func enableVerificationButton(_ enable: Bool) {
        DispatchQueue.main.async {
            if enable {
                self.getVerificationEmailButton.hideLoading()
                self.getVerificationEmailButton.isEnabled = true
            } else {
                self.getVerificationEmailButton.isEnabled = false
                self.getVerificationEmailButton.showLoading()
            }
        }
    }

    // MARK: User actions
    
    @IBAction func backgroundTapped(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func emailWrapperTapped(_ sender: Any) {
        emailField.becomeFirstResponder()
    }
    
    @IBAction func getEmailButtonTapped(_ sender: Any) {
        emailField.resignFirstResponder()
        viewModel?.verify(email: emailField.text ?? "")
    }
    
}

extension VerificationEmailViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        
        getVerificationEmailButton.isEnabled = !currentText.isEmpty
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        getEmailButtonTapped(textField)
        
        return true
    }
}
