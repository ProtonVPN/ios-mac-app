//
//  UserAccountUpdateViewController.swift
//  ProtonVPN - Created on 06.04.21.
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

class UserAccountUpdateViewController: NSViewController {

    @IBOutlet weak var serversView: NSView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var titleLbl: NSTextField!
    @IBOutlet weak var descriptionLbl: NSTextField!
    @IBOutlet weak var offsetView: NSView!
    
    @IBOutlet weak var featuresTitleLbl: NSTextField!
    
    @IBOutlet weak var primaryActionBtn: NSButton!
    @IBOutlet weak var secondActionBtn: NSButton!
    
    @IBOutlet weak var feature1View: NSView!
    @IBOutlet weak var feature1Lbl: NSTextField!
    
    @IBOutlet weak var feature2View: NSView!
    @IBOutlet weak var feature2Lbl: NSTextField!
    
    @IBOutlet weak var feature3View: NSView!
    @IBOutlet weak var feature3Lbl: NSTextField!
    
    @IBOutlet weak var fromServerTitleLbl: NSTextField!
    @IBOutlet weak var fromServerIV: NSImageView!
    @IBOutlet weak var fromServerLbl: NSTextField!
    
    @IBOutlet weak var toServerTitleLbl: NSTextField!
    @IBOutlet weak var toServerIV: NSImageView!
    @IBOutlet weak var toServerLbl: NSTextField!
    
    private let alert: UserAccountUpdateAlert
    var dismissCompletion: (() -> Void)?
    
    init( alert: UserAccountUpdateAlert ) {
        self.alert = alert
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ProtonVPN"
        serversView.wantsLayer = true
        serversView.layer?.backgroundColor = #colorLiteral(red: 0.1450980392, green: 0.1529411765, blue: 0.1725490196, alpha: 1)
        serversView.layer?.cornerRadius = 8
        
        imageView.isHidden = alert.imageName == nil
        if let imageName = alert.imageName { imageView.image = NSImage(named: imageName) }
        
        titleLbl.stringValue = alert.title ?? ""
        descriptionLbl.stringValue = alert.message ?? ""
        
        setupFeatures()
        setupActions()
        setupServers()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        alert.dismiss?()
    }

    // MARK: - Private
    
    private func setupFeatures() {
        feature1View.isHidden = !alert.displayFeatures
        feature2View.isHidden = !alert.displayFeatures
        feature3View.isHidden = !alert.displayFeatures
        featuresTitleLbl.isHidden = !alert.displayFeatures
        feature1Lbl.stringValue = LocalizedString.subscriptionUpgradeOption1(54)
        feature2Lbl.stringValue = LocalizedString.subscriptionUpgradeOption2(5)
        feature3Lbl.stringValue = LocalizedString.subscriptionUpgradeOption3
    }
    
    private func setupActions() {
        primaryActionBtn.isHidden = true
        secondActionBtn.isHidden = true
        
        if let mainAction = alert.actions.first {
            primaryActionBtn.title = mainAction.title.capitalized
            primaryActionBtn.isHidden = false
        }
        
        if let secondAction = alert.actions.last {
            secondActionBtn.title = secondAction.title.capitalized
            secondActionBtn.isHidden = false
        }
    }
    
    private func setupServers() {
        offsetView.isHidden = true
        serversView.isHidden = true
        guard let fromServer = alert.reconnectionInfo?.from,
              let toServer = alert.reconnectionInfo?.to else {
            return
        }
        
        offsetView.isHidden = false
        serversView.isHidden = false
        setServerHeader(fromServer, LocalizedString.fromServerTitle, fromServerIV, fromServerLbl, fromServerTitleLbl)
        setServerHeader(toServer, LocalizedString.toServerTitle, toServerIV, toServerLbl, toServerTitleLbl)
    }
    
    private func setServerHeader( _ server: ServerModel, _ headerFormat: String, _ flagIV: NSImageView, _ serverName: NSTextField, _ serverHeader: NSTextField ) {
        serverName.stringValue = server.name
        flagIV.image = NSImage(named: server.countryCode.lowercased() + "-plain")
        serverHeader.stringValue = String(format: headerFormat, serverType(server))
    }
    
    private func serverType( _ server: ServerModel ) -> String {
        let tiers = [ LocalizedString.tierFREE, LocalizedString.tierBASIC,
                      LocalizedString.tierPLUS, LocalizedString.tierVISIONARY]
        
        return tiers[server.tier]
    }
    
    // MARK: - Actions
    
    @IBAction func didTapPrimaryAction(_ sender: Any) {
        alert.actions.first?.handler?()
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
        dismissCompletion?()
        dismiss(nil)
    }
    
    @IBAction func didTapSecondAction(_ sender: Any) {
        alert.actions.last?.handler?()
        dismissCompletion?()
        dismiss(nil)
    }
}
