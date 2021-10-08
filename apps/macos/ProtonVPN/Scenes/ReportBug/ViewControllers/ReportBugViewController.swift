//
//  ReportBugViewController.swift
//  ProtonVPN - Created on 05/07/2019.
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

class ReportBugViewController: NSViewController {
    
    private let viewModel: ReportBugViewModel
    private let alertService: CoreAlertService
    @IBOutlet private weak var horizontalLineEmail: NSView!
    @IBOutlet private weak var emailLabel: PVPNTextField!
    @IBOutlet private weak var emailField: TextFieldWithFocus!
    @IBOutlet private weak var feedbackLabel: PVPNTextField!
    @IBOutlet private weak var feedbackTextField: NSTextField!
    @IBOutlet private weak var stepsLabel: PVPNTextField!
    @IBOutlet private weak var stepsTextField: NSTextField!
    @IBOutlet private weak var cancelButton: ClearCancellationButton!
    @IBOutlet private weak var sendButton: PrimaryActionButton!
    @IBOutlet private weak var contentContainerView: NSView!
    @IBOutlet private weak var loadingView: NSView!
    @IBOutlet private weak var loadingSymbol: LoadingAnimationView!
    @IBOutlet private weak var loadingLabel: PVPNTextField!
    
    @IBOutlet weak var attachFilesCheckBox: NSButton!
    @IBOutlet weak var attachFilesImage: NSImageView!
    
    private var fieldFont = NSFont.systemFont(ofSize: 14)
    private var borderlessButtonFont = NSFont.systemFont(ofSize: 14, weight: .bold)
    private var logs: [URL] = []
    private var logFileUrl: URL? {
        return PMLog.logFile()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(viewModel: ReportBugViewModel, alertService: CoreAlertService, vpnManager: VpnManagerProtocol) {
        self.viewModel = viewModel
        self.alertService = alertService
        super.init(nibName: NSNib.Name("ReportBugViewController"), bundle: nil)
        
        // Add app log file
        if let url = logFileUrl {
            self.logs.append(url)
        }
        // Add ovpn log file
        vpnManager.logsContent(for: .openVpn(.undefined)) { logs in
            let filename = AppConstants.Filenames.openVpnLogFilename
            if let content = logs {
                PMLog.dump(logs: content, toFile: filename)
            }
            // This is NOT inside the last `if`, because there may already be a log file
            if let url = PMLog.logFile(filename), FileManager.default.fileExists(atPath: url.path) {
                self.logs.append(url)
            }
        }
        // Add wireguard log file
        vpnManager.logsContent(for: .wireGuard) { logs in
            let filename = AppConstants.Filenames.wireGuardLogFilename
            if let content = logs {
                PMLog.dump(logs: content, toFile: filename)
            }
            // This is NOT inside the last `if`, because there may already be a log file
            if let url = PMLog.logFile(filename), FileManager.default.fileExists(atPath: url.path) {
                self.logs.append(url)
            }
        }
    }
    
    deinit {
        loadingSymbol.animate(false)
    }
 
    override func viewWillAppear() {
        super.viewWillAppear()
        setupDesign()
        setupTranslations()
        setupLoadingView()
        fillDataFromModel()
        setupButtonActions()
    }
    
    private func setupDesign() {
        horizontalLineEmail.wantsLayer = true
        horizontalLineEmail.layer?.backgroundColor = NSColor.protonLightGrey().cgColor
        sendButton.actionType = .confirmative
        attachFilesImage.image = NSImage(named: NSImage.Name("info_green"))
        attachFilesImage.toolTip = LocalizedString.reportDescription
    }
    
    private func setupTranslations() {
        emailLabel.stringValue = LocalizedString.reportFieldEmail
        feedbackLabel.stringValue = LocalizedString.reportFieldFeedback
        stepsLabel.stringValue = LocalizedString.reportFieldSteps
        stepsTextField.placeholderString = LocalizedString.reportFieldPlaceholder
        feedbackTextField.placeholderString = LocalizedString.reportFieldPlaceholder
        attachFilesCheckBox.title = LocalizedString.reportAttachmentsCheckbox
        cancelButton.title = LocalizedString.cancel
        sendButton.title = LocalizedString.submitVerificationCode
    }
    
    private func setupButtonActions() {
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonPressed)
        
        sendButton.target = self
        sendButton.action = #selector(sendButtonPressed)
    }
    
    private func fillDataFromModel() {
        emailField.stringValue = viewModel.getEmail() ?? ""
    }
    
    private func renderSendButton() {
        sendButton.isEnabled = viewModel.isSendingPossible
            && emailField.stringValue.isEmail
            && !feedbackTextField.stringValue.isEmpty
            && !stepsTextField.stringValue.isEmpty
    }
    
    // MARK: - Loading screen
    
    private func setupLoadingView() {
        loadingView.isHidden = true
        
        let font = NSFont.systemFont(ofSize: 18)
        let fontManager = NSFontManager()
        let italicizedFont = fontManager.convert(font, toHaveTrait: [.italicFontMask])
        loadingLabel.attributedStringValue = LocalizedString.loadingScreenSlogan.attributed(withColor: .protonWhite(), font: italicizedFont)
    }
    
    private func presentLoadingScreen() {
        contentContainerView.isHidden = true
        loadingView.isHidden = false
        loadingSymbol.animate(true)
    }
    
    private func hideLoadingScreen() {
        contentContainerView.isHidden = false
        loadingView.isHidden = true
        loadingSymbol.animate(false)
    }
    
    // MARK: - Button actions

    @objc func cancelButtonPressed() {
        self.view.window!.performClose(nil)
    }
    
    @objc func sendButtonPressed() {
        
        if attachFilesCheckBox.state == .on {
            viewModel.add(files: logs)
        } else {
            viewModel.removeAllFiles()
        }
        
        presentLoadingScreen()
        viewModel.send(success: {
            self.hideLoadingScreen()
            self.view.window!.close()
        }, error: { error in
            PMLog.ET(error.localizedDescription)
            self.hideLoadingScreen()            
            self.alertService.push(alert: UnknownErrortAlert(error: error, confirmHandler: nil))
        })
    }
}

// MARK: - Feedback placeholder

extension ReportBugViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        
        switch field {
        case emailField:
            viewModel.set(email: field.stringValue)
            
        case stepsTextField, feedbackTextField:
            let description = LocalizedString.reportFieldFeedback
                + "\n\n"
                + feedbackTextField.stringValue
                + "\n\n"
                + LocalizedString.reportFieldSteps
                + "\n\n"
                + stepsTextField.stringValue
            
            viewModel.set(description: description)
        default:
            return
        }
        renderSendButton()
    }
}
