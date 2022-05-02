//
//  Created on 02/05/2022.
//
//  Copyright (c) 2022 Proton AG
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

import AppKit
import vpncore

protocol TwoFactorDelegate: class {
    func twoFactorButtonAction(code: String)
    func backAction()
}

final class TwoFactorView: NSView {
    @IBOutlet private weak var twoFactorTextField: TextFieldWithFocus!
    @IBOutlet private weak var twoFactorHorizontalLine: NSBox!
    @IBOutlet private weak var twoFactorButton: LoginButton!
    @IBOutlet private weak var twoFactorModeButton: InteractiveActionButton!
    @IBOutlet private weak var twoFactorTitle: NSTextField!
    @IBOutlet private weak var backButton: NSButton!

    private var isRecoveryCodeMode = false

    weak var delegate: TwoFactorDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    private func setup() {
        twoFactorHorizontalLine.fillColor = .color(.border, .weak)

        twoFactorTextField.delegate = self
        twoFactorTextField.textColor = .color(.text)
        twoFactorTextField.font = .themeFont(.paragraph)
        twoFactorTextField.placeholderAttributedString = LocalizedString.twoFactorCode.styled(.weak, font: .themeFont(.small), alignment: .left)
        twoFactorTextField.usesSingleLineMode = true

        twoFactorButton.isEnabled = false
        twoFactorButton.target = self
        twoFactorButton.action = #selector(twoFactorButtonAction)

        twoFactorButton.displayTitle = LocalizedString.authenticate

        twoFactorModeButton.title = LocalizedString.useRecoveryCode
        twoFactorModeButton.target = self
        twoFactorModeButton.action = #selector(switchTwoFactorModeAction)

        twoFactorTitle.stringValue = LocalizedString.twoFactorAuthentication
        twoFactorTitle.textColor = .color(.text)

        backButton.target = self
        backButton.action = #selector(backAction)
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        twoFactorHorizontalLine.fillColor = .color(.border, .interactive)

        return twoFactorTextField.becomeFirstResponder()
    }

    @objc func twoFactorButtonAction() {
        delegate?.twoFactorButtonAction(code: twoFactorTextField.stringValue)
    }

    @objc func switchTwoFactorModeAction() {
        twoFactorModeButton.title = isRecoveryCodeMode ? LocalizedString.useTwoFactorCode : LocalizedString.useRecoveryCode
        twoFactorTextField.placeholderString = isRecoveryCodeMode ? LocalizedString.recoveryCode : LocalizedString.twoFactorCode

        isRecoveryCodeMode.toggle()
    }

    @objc func backAction() {
        delegate?.backAction()
    }
}

extension TwoFactorView: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        twoFactorButton.isEnabled = !twoFactorTextField.stringValue.isEmpty
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control == twoFactorTextField {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) && twoFactorButton.isEnabled {
                twoFactorButtonAction()
                return true
            }
            return false
        }

        return false
    }
}
