//
//  SignUpSmsViewController.swift
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

class VerificationSmsViewController: UIViewController {

    private let stackViewBottomConstraintConstant: CGFloat = 171
    private let fieldFontSize: CGFloat = 18
        
    @IBOutlet weak var textFieldStackView: UIStackView!
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var underLogoLabel: UILabel!
    
    @IBOutlet weak var codeAndPhoneWrapper: UIView!
    @IBOutlet weak var codeField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    
    @IBOutlet weak var verifyButton: ProtonButton!
    
    var viewModel: VerificationSmsViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        
        setupCodeField()
        setupPhoneTextField()
        setupVerificationButton()
        
        viewModel?.verificationButtonEnabled = { [weak self] enabled in
            self?.enableVerificationButton(enabled)
        }
        viewModel?.codeChanged = { [weak self] in
            self?.updateCodeField()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        updateCodeField()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        phoneField.resignFirstResponder()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Setup
        
    private func setupCodeField() {
        codeAndPhoneWrapper.backgroundColor = view.backgroundColor
        
        codeField.attributedPlaceholder = LocalizedString.phoneCountryCodePlaceholder.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        codeField.textColor = .protonWhite()
        codeField.minimumFontSize = fieldFontSize
    }
    
    private func setupPhoneTextField() {
        phoneField.delegate = self
        phoneField.attributedPlaceholder = LocalizedString.phoneNumberPlaceholder.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        phoneField.textColor = .protonWhite()
        phoneField.minimumFontSize = fieldFontSize
        phoneField.keyboardType = .phonePad
    }
    
    private func setupVerificationButton() {
        verifyButton.setTitle(LocalizedString.getVerificationSms, for: .normal)
    }
    
    private func updateCodeField() {
        codeField.text = viewModel?.code
    }
        
    private func enableVerificationButton(_ enable: Bool) {
        DispatchQueue.main.async {
            if enable {
                self.verifyButton.hideLoading()
                self.verifyButton.isEnabled = true
            } else {
                self.verifyButton.isEnabled = false
                self.verifyButton.showLoading()
            }
        }
    }
    
    // MARK: User actions
    
    @IBAction func backgroundTapped(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func changeCode(_ sender: Any) {
        viewModel?.showCountryCodeScreen()
    }
    
    @IBAction func phoneWrapperTapped(_ sender: Any) {
        phoneField.becomeFirstResponder()
    }
    
    @IBAction func getVerificationCodeTapped(_ sender: Any) {
        viewModel?.verify()
        phoneField.resignFirstResponder()
    }
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        changeConstraintBasedOnKeyboardChange(notification, constraint: stackViewBottomConstraint, maxConstraintConstant: stackViewBottomConstraintConstant)
    }
}

extension VerificationSmsViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let proposedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        
        viewModel?.phone = proposedText
        
        verifyButton.isEnabled = !proposedText.isEmpty
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        getVerificationCodeTapped(textField)
        return true
    }
}
