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
    
    let viewModel: ReportBugViewModel
    private let alertService: CoreAlertService
    
    @IBOutlet weak var horizontalLineEmail: NSBox!
    @IBOutlet weak var horizontalLineCountry: NSBox!
    @IBOutlet weak var horizontalLineIsp: NSBox!
    
    @IBOutlet weak var descriptionLabel: PVPNTextField!
    @IBOutlet weak var emailLabel: PVPNTextField!
    @IBOutlet weak var contryLabel: PVPNTextField!
    @IBOutlet weak var fileSizeLabel: PVPNTextField!
    @IBOutlet weak var ispLabel: PVPNTextField!
    @IBOutlet weak var accountLabel: PVPNTextField!
    @IBOutlet weak var accountValueLabel: PVPNTextField!
    @IBOutlet weak var planLabel: PVPNTextField!
    @IBOutlet weak var planValueLabel: PVPNTextField!
    @IBOutlet weak var versionLabel: PVPNTextField!
    @IBOutlet weak var versionValueLabel: PVPNTextField!
    @IBOutlet weak var feedbackLabel: PVPNTextField!
    @IBOutlet weak var feedbackPlaceholderLabel: PVPNTextField!
    
    @IBOutlet weak var emailField: TextFieldWithFocus!
    @IBOutlet weak var countryField: TextFieldWithFocus!
    @IBOutlet weak var ispField: TextFieldWithFocus!
    @IBOutlet weak var feedbackField: NSTextView!
    @IBOutlet weak var feedbackContainer: NSScrollView!
    
    @IBOutlet weak var filesTableView: NSTableView!
    
    @IBOutlet weak var attachmentButton: NSButton!
    @IBOutlet weak var cancelButton: ClearCancellationButton!
    @IBOutlet weak var sendButton: PrimaryActionButton!
    
    @IBOutlet weak var contentContainerView: NSView!
    
    @IBOutlet weak var loadingView: NSView!
    @IBOutlet weak var loadingSymbol: LoadingAnimationView!
    @IBOutlet weak var loadingLabel: PVPNTextField!
    
    private var fieldFont = NSFont.systemFont(ofSize: 14)
    private var borderlessButtonFont = NSFont.systemFont(ofSize: 14, weight: .bold)
    
    private var logFileUrl: URL? {
        return PMLog.logFile()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(viewModel: ReportBugViewModel, alertService: CoreAlertService) {
        self.viewModel = viewModel
        self.alertService = alertService
        super.init(nibName: NSNib.Name("ReportBugViewController"), bundle: nil)
        
        if let url = logFileUrl {
            viewModel.add(files: [url])
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
        setupFilesTable()
        
        viewModel.attachmentsListRefreshed = {[weak self] in
            self?.filesTableView.reloadData()
        }
    }
    
    private func setupDesign() {
        [horizontalLineEmail, horizontalLineCountry, horizontalLineIsp].forEach { view in 
            view.fillColor = .protonLightGrey()
        }
        
        sendButton.actionType = .confirmative
        fileSizeLabel.textColor = .protonLightGrey()
        feedbackPlaceholderLabel.textColor = .protonLightGrey()
        feedbackField.backgroundColor = NSColor.protonGrey()
        feedbackField.textColor = NSColor.protonWhite()
        feedbackContainer.backgroundColor = NSColor.protonGrey()
        
        feedbackField.font = fieldFont
        [emailField, countryField, ispField].forEach({ element in
            element?.font = fieldFont
        })
        
        if #available(OSX 10.14, *) {
            attachmentButton.contentTintColor = .protonGreen()
        }
    }
    
    private func setupFilesTable() {
        filesTableView.dataSource = self
        filesTableView.delegate = self
        filesTableView.ignoresMultiClick = true
        filesTableView.selectionHighlightStyle = .none
        filesTableView.backgroundColor = .protonGrey()
        filesTableView.register(NSNib(nibNamed: NSNib.Name(String(describing: AttachedFileView.self)), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: String(describing: AttachedFileView.self)))
    }
    
    private func setupTranslations() {
        descriptionLabel.stringValue = LocalizedString.reportDescription
        emailLabel.stringValue = LocalizedString.reportFieldEmail
        contryLabel.stringValue = LocalizedString.reportFieldCountry
        fileSizeLabel.stringValue = LocalizedString.reportMaxFileSize
        ispLabel.stringValue = LocalizedString.reportFieldISP
        accountLabel.stringValue = LocalizedString.reportFieldAccount
        planLabel.stringValue = LocalizedString.reportFieldPlan
        versionLabel.stringValue = LocalizedString.reportFieldVersion
        feedbackLabel.stringValue = LocalizedString.reportFieldFeedback
        feedbackPlaceholderLabel.stringValue = LocalizedString.reportPlaceholderMessage
        
        cancelButton.title = LocalizedString.cancel
        sendButton.title = LocalizedString.reportSend
        attachmentButton.attributedTitle = LocalizedString.reportAddFile.attributed(withColor: .protonGreen(), font: borderlessButtonFont)
    }
    
    private func setupButtonActions() {
        attachmentButton.target = self
        attachmentButton.action = #selector(addFilePressed)
        
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonPressed)
        
        sendButton.target = self
        sendButton.action = #selector(sendButtonPressed)
    }
    
    private func fillDataFromModel() {
        emailField.stringValue = viewModel.getEmail() ?? ""
        countryField.stringValue = viewModel.getCountry() ?? ""
        ispField.stringValue = viewModel.getISP() ?? ""
        
        accountValueLabel.stringValue = viewModel.getUsername() ?? ""
        versionValueLabel.stringValue = viewModel.getClientVersion() ?? ""
        
        if let accountPlan = viewModel.getAccountPlan() {
            planValueLabel.textColor = accountPlan.colorForUI
            planValueLabel.stringValue = accountPlan.description
        } else {
            planValueLabel.textColor = .protonGreyOutOfFocus()
            planValueLabel.stringValue = LocalizedString.unavailable
        }
        renderFeedbackPlaceholder()
    }
    
    private func renderSendButton() {
        sendButton.isEnabled = viewModel.isSendingPossible
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
    
    @objc func addFilePressed() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = logFileUrl
        
        panel.beginSheetModal(for: self.view.window!) { (result) in
            if result == NSApplication.ModalResponse.OK {
                self.viewModel.add(files: panel.urls)
            }
        }
    }
    
    @objc func cancelButtonPressed() {
        self.view.window!.performClose(nil)
    }
    
    @objc func sendButtonPressed() {
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

// MARK: - Attachments Table

extension ReportBugViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.filesCount
    }
}

extension ReportBugViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30.0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: String(describing: AttachedFileView.self)), owner: nil) as! AttachedFileView
        
        let rowViewModel = viewModel.fileAttachment(atRow: row)
        cellView.updateView(viewModel: rowViewModel)
        
        return cellView
    }
    
}

// MARK: - Feedback placeholder

extension ReportBugViewController: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        viewModel.set(description: feedbackField.string)
        renderFeedbackPlaceholder()
        renderSendButton()
    }
    
    func renderFeedbackPlaceholder() {
        feedbackPlaceholderLabel.isHidden = !feedbackField.string.isEmpty
    }
    
}

extension ReportBugViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        
        if field == emailField {
            viewModel.set(email: field.stringValue)
        } else if field == countryField {
            viewModel.set(country: field.stringValue)
        } else if field == ispField {
            viewModel.set(isp: field.stringValue)
        }
        renderSendButton()
    }
    
}
