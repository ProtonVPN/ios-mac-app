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
import vpncore

final class SubuserMacAlertViewController: NSViewController {
    
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var titleView: NSTextField!
    @IBOutlet private weak var description1Label: NSTextField!
    @IBOutlet private weak var description2Label: NSTextField!
        
    @IBOutlet private weak var assignConnectionsButton: PrimaryActionButton!
    @IBOutlet private weak var loginButton: WhiteCancelationButton!
    
    public var safariServiceFactory: SafariServiceFactory?
    private lazy var safariService = safariServiceFactory?.makeSafariService()
    
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
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.subuserAlertTitle)
    }
    
    private func setupTranslations() {
        titleView.stringValue = LocalizedString.subuserAlertTitle
        description1Label.stringValue = LocalizedString.subuserAlertDescription1
        description2Label.stringValue = LocalizedString.subuserAlertDescription2
        assignConnectionsButton.title = LocalizedString.subuserAlertAssignConnectionsButton
        loginButton.title = LocalizedString.subuserAlertLoginButton
    }
    
    private func setupViews() {
        imageView.image = Bundle.vpnCore.image(forResource: NSImage.Name("alert-pro-account"))
        
        assignConnectionsButton.actionType = .confirmative
        assignConnectionsButton.isEnabled = true
        loginButton.isEnabled = true
        
        titleView.textColor = .protonWhite()
        description1Label.textColor = .protonWhite()
        description2Label.textColor = .protonFontLightGrey()
                
    }
    
    // MARK: - Actions
    
    @IBAction private func assignConnectionsTapped(_ sender: NSButton) {
        safariService?.open(url: CoreAppConstants.ProtonVpnLinks.assignVPNConnections)
    }
    
    @IBAction func loginTapped(_ sender: NSButton) {
        view.window?.close()
    }
    
}
