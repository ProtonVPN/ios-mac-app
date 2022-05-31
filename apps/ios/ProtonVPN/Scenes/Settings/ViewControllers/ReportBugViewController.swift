//
//  ReportsApiService.swift
//  ProtonVPN - Created on 28/06/2019.
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

class ReportBugViewController: UIViewController {
    
    public var viewModel: ReportBugViewModel!
    public var appLogFileUrl: URL?
    
    private let vpnManager: VpnManagerProtocol
    
    private let fieldFontSize: CGFloat = 16
    private let textFontSize: CGFloat = 14
    
    @IBOutlet weak var attachmentsLabel: UILabel!
    @IBOutlet weak var logsLabel: UILabel!
    @IBOutlet weak var logsDescriptionLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var messagePlaceHolderLabel: UILabel!
    @IBOutlet weak var lineView: UIView!
    @IBOutlet weak var logsSwitch: UISwitch!
    @IBOutlet weak var emailHolderView: UIView!
    @IBOutlet weak var messageHolderView: UIView!
    @IBOutlet weak var sendButton: ProtonButton!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var messageField: UITextView!
    @IBOutlet weak var scrollView: UIScrollView!
    // Keyboard
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    private let footerConstraintConstant: CGFloat = 0
    private var scrollViewClick: UITapGestureRecognizer!

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(vpnManager: VpnManagerProtocol) {
        self.vpnManager = vpnManager
        
        super.init(nibName: "ReportBugViewController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        logsSwitch.accessibilityIdentifier = "vpn logs"
        view.backgroundColor = .backgroundColor()
        lineView.backgroundColor = .secondaryBackgroundColor()
        navigationController?.navigationBar.backgroundColor = .secondaryBackgroundColor()
        
        let closeButton = UIButton.closeButton()
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        self.title = LocalizedString.reportBug
        
        setupInputHolder(view: emailHolderView, placeholder: LocalizedString.reportPlaceholderEmail)
        setupInputHolder(view: messageHolderView, placeholder: LocalizedString.reportPlaceholderMessage)
        messageField.delegate = self
        
        setupHeader(label: attachmentsLabel, text: LocalizedString.reportAttachments)
        setupHeader(label: messageLabel, text: LocalizedString.reportReport)
        setupSubHeader(label: logsLabel, text: LocalizedString.reportLogs)
        setupDescription(label: logsDescriptionLabel, text: LocalizedString.reportLogsDescription)
        
        sendButton.setTitle(LocalizedString.reportSend, for: .normal)
        
        scrollViewClick = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        scrollView.addGestureRecognizer(scrollViewClick)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logsSwitch.isOn = true
        logsSwitchChanged()
        renderButton()
        emailField.text = viewModel.getEmail()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    func renderButton() {
        sendButton.isEnabled = viewModel.isSendingPossible
    }
    
    @IBAction func logsSwitchChanged() {
        if logsSwitch.isOn {
            if let applicationLogFile = appLogFileUrl {
                viewModel.add(files: [applicationLogFile])
            }
            
            if let fileUrl = vpnManager.logFile(for: .openVpn(.tcp)) {
                viewModel.add(files: [fileUrl])
            }
            
            if let fileUrl = vpnManager.logFile(for: .wireGuard) {
                viewModel.add(files: [fileUrl])
            }
            
        } else {
            viewModel.removeAllFiles()
        }
    }
    
    @IBAction func emailChanged() {
        viewModel.set(email: emailField.text ?? "")
        renderButton()
    }
    
    @IBAction func sendPressed() {
        sendButton.showLoading()
        viewModel.send { result in
            switch result {
            case .success:
                self.sendButton.hideLoading()
                self.close()
            case let .failure(error):
                log.error("\(error.localizedDescription)", category: .ui)
                self.sendButton.hideLoading()
                self.showMessage(error.localizedDescription, type: GSMessageType.error, options: UIConstants.messageOptions)
            }
        }
    }
    
    // MARK: - Private
    
    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func hideKeyboard() {
        view.endEditing(true)
    }
    
    private func setupInputHolder(view: UIView, placeholder: String) {
        view.backgroundColor = .backgroundColor()
        
        for subView in view.subviews where subView is UITextField {
            let textField = subView as! UITextField
            textField.textColor = .normalTextColor()
            textField.font = UIFont.systemFont(ofSize: fieldFontSize)
            textField.attributedPlaceholder = placeholder.attributed(withColor: .weakTextColor(), fontSize: fieldFontSize)
            textField.minimumFontSize = fieldFontSize
        }
        
        for subView in view.subviews where subView is UITextView {
            let textField = subView as! UITextView
            textField.font = UIFont.systemFont(ofSize: fieldFontSize)
            textField.textColor = .normalTextColor()
            textField.backgroundColor = .backgroundColor()
        }
        
        // Placeholder
        for subView in view.subviews where subView is UILabel {
            let label = subView as! UILabel
            label.font = UIFont.systemFont(ofSize: fieldFontSize)
            label.textColor = .weakTextColor()
            label.text = placeholder
        }
    }
    
    private func setupHeader(label: UILabel, text: String) {
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.text = text.uppercased()
        label.textColor = .weakTextColor()
    }
    
    private func setupSubHeader(label: UILabel, text: String) {
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.textColor = .normalTextColor()
        label.text = text
    }
    
    private func setupDescription(label: UILabel, text: String) {
        label.font = UIFont.systemFont(ofSize: textFontSize)
        label.textColor = .weakTextColor()
        label.text = text
    }
    
    // MARK: keyboard
    
    @objc private func keyboardWillChangeFrame(notification: Notification) {
        guard let info = notification.userInfo,
            let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
            let animationCurveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue,
            let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        let animationOptions = UIView.AnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | animationCurveRaw << 16)
        
        if endFrame.minY >= UIScreen.main.bounds.maxY { // Keyboard disappearing
            self.bottomConstraint.constant = self.footerConstraintConstant
        } else {
            self.bottomConstraint.constant = endFrame.size.height
        }
        
        UIView.animate(withDuration: duration, delay: 0, options: animationOptions, animations: { [unowned self] in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
}

extension ReportBugViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        messagePlaceHolderLabel.isHidden = !textView.text.isEmpty
        viewModel.set(description: textView.text)
        renderButton()
    }
    
}

extension ReportBugViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            messageField.becomeFirstResponder()
            return false
        }
        return true
    }
    
}
