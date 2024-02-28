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
import LegacyCommon
import Theme
import Ergonomics
import Strings

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

    @IBOutlet weak var fromToArrow: NSImageView!

    @IBOutlet weak var toServerTitleLbl: NSTextField!
    @IBOutlet weak var toServerIV: NSImageView!
    @IBOutlet weak var toServerLbl: NSTextField!

    private let alert: UserAccountUpdateAlert
    private let sessionService: SessionService

    var dismissCompletion: (() -> Void)?
    
    init(alert: UserAccountUpdateAlert, sessionService: SessionService) {
        self.alert = alert
        self.sessionService = sessionService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Proton VPN"
        view.wantsLayer = true
        serversView.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
            serversView.layer?.backgroundColor = .cgColor(.background, .weak)
            fromToArrow.image = AppTheme.Icon.arrowRight.colored(.weak)
        }
        serversView.layer?.cornerRadius = 8

        if alert is MaxSessionsAlert {
            imageView.image = Asset.sessionsLimit.image
        } else {
            imageView.isHidden = true
        }

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
        guard alert.displayFeatures else { return }
        feature1Lbl.stringValue = Localizable.subscriptionUpgradeOption1(AccountPlan.plus.countriesCount)
        feature2Lbl.stringValue = Localizable.subscriptionUpgradeOption2(AccountPlan.plus.devicesCount)
        feature3Lbl.stringValue = Localizable.subscriptionUpgradeOption3
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
        guard let reconnectInfo = alert.reconnectInfo else {
            return
        }
        
        offsetView.isHidden = false
        serversView.isHidden = false
        setServerHeader(reconnectInfo.fromServer, Localizable.fromServerTitle, fromServerIV, fromServerLbl, fromServerTitleLbl)
        setServerHeader(reconnectInfo.toServer, Localizable.toServerTitle, toServerIV, toServerLbl, toServerTitleLbl)
    }
    
    private func setServerHeader( _ server: ReconnectInfo.Server,
                                  _ header: String,
                                  _ flagIV: NSImageView,
                                  _ serverName: NSTextField,
                                  _ serverHeader: NSTextField ) {
        serverName.stringValue = server.name
        flagIV.image = server.image
        serverHeader.stringValue = header
    }
    
    // MARK: - Actions
    
    @IBAction func didTapPrimaryAction(_ sender: Any) {
        alert.actions.first?.handler?()

        Task {
            let url = await sessionService.getPlanSession(mode: .upgrade)
            SafariService.openLink(url: url)
        }

        dismissCompletion?()
        dismiss(nil)
    }
    
    @IBAction func didTapSecondAction(_ sender: Any) {
        alert.actions.last?.handler?()
        dismissCompletion?()
        dismiss(nil)
    }
}
