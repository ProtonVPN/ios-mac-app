//
//  ProtonTextField.swift
//  ProtonVPN - Created on 12/09/2019.
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

class ProtonTextField: UIView {
    
    enum ContentType {
//        case text
        case email
        case username
        case password
        case oneTimeCode
    }
    
    enum State {
        case normal
        case error(String, String? = nil)
    }
    
    private static let fieldFontSize: CGFloat = 18
    private static let errorFontSize: CGFloat = 14// UIDevice.current.isSmallIphone ? 12 : 14
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var lineView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var showButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet var buttonTextFieldConstraint: NSLayoutConstraint!
    @IBOutlet var errorTopConstraint: NSLayoutConstraint!
    @IBOutlet var errorBottomConstraint: NSLayoutConstraint!
    @IBOutlet var iconTopConstraint: NSLayoutConstraint!
    @IBOutlet var iconBottomConstraint: NSLayoutConstraint!
    
    public var contentType: ContentType = .email { didSet { setupVariety() } }
    public var state: State = .normal { didSet { stateChanged() } }
    
    public var textChanged: ((ProtonTextField) -> Void)?
    public var returnPressed: ((ProtonTextField) -> Void)?
    public var endEditing: ((ProtonTextField) -> Void)?
    
    public var text: String {
        get {
            return textField.text ?? ""
        }
        set {
            textField.text = newValue
            textChanged?(self)
        }
    }
    
    public static func textField(contentType: ContentType, placeholder: String, icon: String?, returnKeyType: UIReturnKeyType = .default) -> ProtonTextField {
        let view = self.loadViewFromNib() as ProtonTextField
        view.contentType = contentType
        view.textField.attributedPlaceholder = placeholder.attributed(withColor: .protonUnavailableGrey(), fontSize: fieldFontSize, lineBreakMode: .byTruncatingTail)
        view.textField.returnKeyType = returnKeyType
        
        if let icon = icon, let iconImage = UIImage(named: icon) {
            view.iconImageView.image = iconImage.withRenderingMode(.alwaysTemplate)
            view.iconImageView.tintColor = .protonUnavailableGrey()
        }
        return view
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .protonTransparent()
        
        showButton.addTarget(self, action: #selector(showButtonTapped(_:)), for: .touchUpInside)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:))))
        textField.textColor = .protonWhite()
        textField.minimumFontSize = ProtonTextField.fieldFontSize
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        stateChanged()
                
    }
    
    func focus() {
        textField.becomeFirstResponder()
    }
    
    // MARK: - Private
    
    @objc func backgroundTapped(_ sender: UIButton) {
        textField.becomeFirstResponder()
    }
    
    private func stateChanged() {
        switch state {
        case .normal:
            lineView.backgroundColor = .protonUnavailableGrey()
            errorLabel.text = ""
            errorLabel.accessibilityIdentifier = nil
            
        case .error(let errorText, let accessibilityIdentifier):
            lineView.backgroundColor = .protonRed()
            errorLabel.text = errorText
            errorLabel.textColor = .protonRed()
            errorLabel.accessibilityIdentifier = accessibilityIdentifier
        }
    }
    
    // swiftlint:disable function_body_length
    private func setupVariety() {
        setupPasswordButton()
        
        switch contentType {
        case .email:
            textField.textContentType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.keyboardType = .emailAddress
            textField.keyboardAppearance = .default
            if #available(iOS 11.0, *) {
                textField.smartDashesType = .no
                textField.smartInsertDeleteType = .no
                textField.smartQuotesType = .no
            }
        case .username:
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if #available(iOS 11.0, *) {
                textField.textContentType = .username
            } else {
                textField.textContentType = .nickname
            }
        case .password:
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.keyboardType = .default
            textField.keyboardAppearance = .default
            if #available(iOS 12.0, *) {
                textField.textContentType = .newPassword
            } else if #available(iOS 11.0, *) {
                textField.textContentType = .password
                textField.smartDashesType = .no
                textField.smartInsertDeleteType = .no
                textField.smartQuotesType = .no
            }
            renderShowPasswordButton()
        case .oneTimeCode:
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.keyboardType = .numberPad
            textField.keyboardAppearance = .default
            if #available(iOS 12.0, *) {
                textField.textContentType = .oneTimeCode
            } else if #available(iOS 11.0, *) {
                textField.smartDashesType = .no
                textField.smartInsertDeleteType = .no
                textField.smartQuotesType = .no
            }
        }
    }
    // swiftlint:enable function_body_length
    
    // MARK: Password
    
    @objc func showButtonTapped(_ sender: UIButton) {
        guard case ContentType.password = contentType else { return }
        textField.isSecureTextEntry = !textField.isSecureTextEntry
        renderShowPasswordButton()
    }
    
    private func renderShowPasswordButton() {
        guard case ContentType.password = contentType else { return }
        showButton.setTitle(textField.isSecureTextEntry ? LocalizedString.show.uppercased() : LocalizedString.hide.uppercased(), for: .normal)
    }
    
    private func setupPasswordButton() {
        if case ContentType.password = contentType {
            showButton.isHidden = false
        } else {
            showButton.isHidden = true
            buttonTextFieldConstraint.isActive = false
        }
    }
    
}

// MARK: UITextFieldDelegate

extension ProtonTextField: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        returnPressed?(self)
        return true
    }
    
    @objc func textChanged(_ sender: UITextField) {
        textChanged?(self)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        endEditing?(self)
    }
}
