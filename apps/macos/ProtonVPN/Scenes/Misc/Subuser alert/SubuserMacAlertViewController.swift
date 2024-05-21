//
//  Created on 2021-11-10.
//
//  Copyright (c) 2021 Proton AG
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
import LegacyCommon
import Strings
import Theme

final class SubuserMacAlertViewController: NSViewController {
    
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var titleView: NSTextField!
    @IBOutlet private weak var description1Label: NSTextField!
    @IBOutlet private weak var description2Label: NSTextField!
        
    @IBOutlet private weak var assignConnectionsButton: PrimaryActionButton!
    @IBOutlet private weak var loginButton: CancellationButton!
    
    var safariServiceFactory: SafariServiceFactory?
    private lazy var safariService = safariServiceFactory?.makeSafariService()
    var role: UserRole = .noOrganization
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init() {
        super.init(nibName: NSNib.Name(String(describing: Self.self)), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTranslations()
        setupViews()
        description1Label.setAccessibilityLabel("description1Label")
        description2Label.setAccessibilityLabel("description2Label")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: Localizable.subuserAlertTitle)
    }
    
    private func setupTranslations() {
        titleView.stringValue = Localizable.subuserAlertTitle

        if role == .organizationAdmin {
            assignConnectionsButton.title = Localizable.subuserAlertEnableConnectionsButton
            assignConnectionsButton.isHidden = false
            description1Label.stringValue = Localizable.subuserAlertDescription1
            description2Label.stringValue = Localizable.subuserAlertDescription2
        } else {
            assignConnectionsButton.isHidden = true
            description1Label.stringValue = Localizable.subuserAlertDescription3
            description2Label.isHidden = true
        }
        loginButton.title = Localizable.subuserAlertLoginButton
    }
    
    private func setupViews() {
        imageView.image = Theme.Asset.icAlertProAccount.image

        assignConnectionsButton.actionType = .confirmative
        assignConnectionsButton.isEnabled = true
        loginButton.isEnabled = true
        
        titleView.textColor = .color(.text)
        description1Label.textColor = .color(.text)
        description2Label.textColor = .color(.text, .weak)
    }
    
    // MARK: - Actions
    
    @IBAction private func assignConnectionsTapped(_ sender: NSButton) {
        safariService?.open(url: CoreAppConstants.ProtonVpnLinks.assignVPNConnections)
    }
    
    @IBAction func loginTapped(_ sender: NSButton) {
        view.window?.close()
    }
}
