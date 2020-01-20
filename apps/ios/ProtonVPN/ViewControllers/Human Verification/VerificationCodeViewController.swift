//
//  VerificationCodeViewController.swift
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

class VerificationCodeViewController: UIViewController {

    // MARK: Properties
    private let visibleConstraintConstant: CGFloat = 171
    private let fieldFontSize: CGFloat = 18
        
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var textFieldStackView: UIStackView!
    @IBOutlet weak var underLogoLabel: UILabel!
    
    @IBOutlet weak var codeWrapperView: UIView!
    @IBOutlet weak var codeField: UITextField!
    
    @IBOutlet weak var verifyCodeButton: ProtonButton!
    @IBOutlet weak var minVisibleConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var resendButton: ProtonButton!
    @IBOutlet weak var resendLabel: UILabel!
        
    var viewModel: VerificationCodeViewModel? {
        didSet {
            viewModel?.verificationButtonEnabled = { [weak self] enabled in
                DispatchQueue.main.async {
                    self?.enableVerificationButton(enabled)
                }
            }
            viewModel?.resendButtonStateChanged = { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.renderResendButtons()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        underLogoLabel.text = LocalizedString.loadingScreenSlogan
        self.navigationItem.title = " " // Remove "Back" from back button on navigation bar
        
        setupCodeTextField()
        setupButtons()
        setupResendButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        codeField.resignFirstResponder()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        verifyCodeButton.hideLoading()
        verifyCodeButton.isEnabled = true
    }
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        changeConstraintBasedOnKeyboardChange(notification, constraint: minVisibleConstraint, maxConstraintConstant: visibleConstraintConstant)
    }
        
    private func setupCodeTextField() {
        instructionLabel.attributedText = LocalizedString.verificationInstructions.attributed(withColor: .protonFontLightGrey(), fontSize: 14, alignment: .center)
        
        codeWrapperView.backgroundColor = view.backgroundColor
        
        codeField.delegate = self
        codeField.textAlignment = .center
        codeField.attributedPlaceholder = LocalizedString.enterVerificationCode.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize)
        codeField.textColor = .protonWhite()
        codeField.minimumFontSize = fieldFontSize
    }
    
    private func setupButtons() {
        verifyCodeButton.isEnabled = false
        verifyCodeButton.setTitle(LocalizedString.submitVerificationCode, for: .normal)
        
        resendButton.customState = .secondary
        resendButton.setTitle(LocalizedString.resendCode, for: .normal)
        resendButton.isHidden = true
    }
        
    private func enableVerificationButton(_ enable: Bool) {
        if enable {
            verifyCodeButton.hideLoading()
            verifyCodeButton.isEnabled = true
        } else {
            verifyCodeButton.isEnabled = false
            verifyCodeButton.showLoading()
        }
    }
    
    // MARK: Resend code
    
    private func setupResendButtons() {
        resendLabel.attributedText = LocalizedString.resendNoCode.attributed(withColor: .protonUnavailableGrey(), fontSize: 14, alignment: .center)
        renderResendButtons()
        resendLabel.isUserInteractionEnabled = true
        resendLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(noCodeTapped)))
    }
    
    private func renderResendButtons() {
        guard let viewModel = viewModel else { return }
        switch viewModel.resendState {
        case .normal:
            resendLabel.isHidden = false
            resendButton.isHidden = true
            resendButton.hideLoading()
            
        case .normalEmpty:
            resendLabel.isHidden = true
            resendButton.isHidden = true
            resendButton.hideLoading()
        
        case .noCode:
            resendLabel.isHidden = true
            resendButton.isHidden = false
            resendButton.hideLoading()
            resendButton.isEnabled = true
            
        case .codeSendingInProgress:
            resendLabel.isHidden = true
            resendButton.isHidden = false
            resendButton.showLoading()
            resendButton.isEnabled = false
        }
    }
    
    // MARK: User actions
    
    @IBAction func backgroundTapped(_ sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func codeWrapperTapped(_ sender: Any) {
        codeField.becomeFirstResponder()
    }
    
    @IBAction func verifyCodeButtonTapped(_ sender: Any) {
        codeField.resignFirstResponder()
        enableVerificationButton(false)
        
        let code = (codeField.text ?? "").replacingOccurrences(of: " ", with: "")
        viewModel?.verify(code: code)
    }
    
    @IBAction func noCodeTapped(_ sender: Any) {
        viewModel?.noCodeReceived()
    }
    
    @IBAction func resendCode(_ sender: Any) {
        viewModel?.resendCode()
    }
}

extension VerificationCodeViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        let currentTextWithoutSpaces = currentText.replacingOccurrences(of: " ", with: "")
        
        verifyCodeButton.isEnabled = !currentTextWithoutSpaces.isEmpty
        textField.text = String(currentTextWithoutSpaces.prefix(6))
        
        return false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        verifyCodeButtonTapped(textField)
        
        return true
    }
}
