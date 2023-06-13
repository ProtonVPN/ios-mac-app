//
//  Created on 12.04.2022.
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

import Cocoa
import vpncore
import Theme

protocol CouponViewControllerDelegate: AnyObject {
    func userDidCloseCouponViewController()
    func couponDidApply(message: String)
}

final class CouponViewController: NSViewController {
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var applyButton: PrimaryActionButton!
    @IBOutlet private weak var errorLabel: NSTextField!
    @IBOutlet private weak var textField: TextFieldWithFocus!
    @IBOutlet private weak var textFieldHorizontalLine: NSBox!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var tooltipTriangle: NSImageCell!

    weak var delegate: CouponViewControllerDelegate?

    private let viewModel: CouponViewModel

    init(viewModel: CouponViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "CouponViewController", bundle: nil)

        viewModel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupActions()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        applyButton.isHovered = false
    }

    private func setupUI() {
        view.wantsLayer = true

        let shadow = NSShadow()
        shadow.shadowColor = .color(.background)
        shadow.shadowBlurRadius = 8
        view.shadow = shadow
        view.layer?.masksToBounds = false
        view.layer?.shadowRadius = 5

        tooltipTriangle.image = Asset.reverseTriangle.image.colored(context: .background)
        applyButton.title = LocalizedString.applyCoupon

        textField.textColor = .color(.text)
        textField.font = .themeFont()
        textField.placeholderAttributedString = LocalizedString.couponCode.styled(.weak, alignment: .left)
        textField.usesSingleLineMode = true
        textField.delegate = self
        textField.focusDelegate = self

        closeButton.image = AppTheme.Icon.crossSmall

        setLineColors(isFirstResponder: false)
        errorLabel.textColor = .color(.text, .danger)

        progressIndicator.set(tintColor: .color(.icon, .interactive))
    }

    private func setupActions() {
        closeButton.target = self
        closeButton.action = #selector(close)

        applyButton.target = self
        applyButton.action = #selector(apply)
    }

    @objc private func close() {
        delegate?.userDidCloseCouponViewController()
    }

    @objc private func apply() {
        _ = textField.resignFirstResponder()

        viewModel.applyPromoCode(code: textField.stringValue) { [weak self] result in
            switch result {
            case let .success(message):
                self?.delegate?.couponDidApply(message: message)
            case let .failure(error):
                self?.setErrorMessage(message: error.localizedDescription)
            }
        }
    }

    private func setErrorMessage(message: String?) {
        guard let message = message, !message.isEmpty else {
            errorLabel.attributedStringValue = "".styled(.danger)
            return
        }

        let font: NSFont = .themeFont()
        let icon = AppTheme.Icon.exclamationCircleFilled.asAttachment(style: .danger,
                                                                      size: .square(16),
                                                                      centeredVerticallyForFont: font)
        let text = NSMutableAttributedString(
            string: " " + message,
            attributes: [
                .font: font,
                .baselineOffset: 3,
                .foregroundColor: NSColor.color(.text, .danger)
            ]
        )
        errorLabel.attributedStringValue = NSAttributedString.concatenate(icon, text)
    }

    private func setLineColors(isFirstResponder: Bool) {
        let color: NSColor
        if viewModel.isError {
            color = .color(.border, .danger)
        } else if isFirstResponder {
            color = .color(.border, .interactive)
        } else {
            color = .color(.border, .weak)
        }
        textFieldHorizontalLine.fillColor = color
    }

    func focus() {
        _ = textField.becomeFirstResponder()
    }
}

// MARK: NSTextFieldDelegate
extension CouponViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let normalized = textField.stringValue.uppercased()
        if textField.stringValue != normalized {
            textField.stringValue = normalized
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            apply()
            return true
        }
        return false
    }
}

// MARK: TextFieldFocusDelegate
extension CouponViewController: TextFieldFocusDelegate {
    var shouldBecomeFirstResponder: Bool { true }

    func didLoseFocus(_ textField: NSTextField) {
        setLineColors(isFirstResponder: false)
    }

    func willReceiveFocus(_ textField: NSTextField) {
        setLineColors(isFirstResponder: true)
    }
}

// MARK: CouponViewModelDelegate
extension CouponViewController: CouponViewModelDelegate {
    func loadingDidChange(isLoading: Bool) {
        applyButton.isEnabled = !isLoading

        if isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }

    func errorDidChange(isError: Bool) {
        setLineColors(isFirstResponder: false)
        if !isError {
            setErrorMessage(message: nil)
        }
    }
}
