//
//  Created on 2021-11-08.
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

import Foundation
import UIKit
import LegacyCommon
import Theme
import Strings

class SubuserAlertViewController: UIViewController {
    
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var description1Label: UILabel!
    @IBOutlet private weak var description2Label: UILabel!
    @IBOutlet private weak var assignConnectionsButton: ProtonButton!
    @IBOutlet private weak var loginButton: ProtonButton!

    var role: UserRole = .noOrganization
    
    public var safariServiceFactory: SafariServiceFactory?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTranslations()
        setupViews()
        description1Label.accessibilityIdentifier = "subuserAlertDescription1"
        description2Label.accessibilityIdentifier = "subuserAlertDescription2"
    }
    
    private func setupTranslations() {
        titleLabel.text = Localizable.subuserAlertTitle
        if role == .organizationAdmin {
            assignConnectionsButton.setTitle(Localizable.subuserAlertEnableConnectionsButton, for: .normal)
            assignConnectionsButton.isHidden = false
            description1Label.text = Localizable.subuserAlertDescription1
            description2Label.text = Localizable.subuserAlertDescription2
        } else {
            assignConnectionsButton.isHidden = true
            description1Label.text = Localizable.subuserAlertDescription3
            description2Label.isHidden = true
        }

        loginButton.setTitle(Localizable.subuserAlertLoginButton, for: .normal)
    }
    
    private func setupViews() {
        view.backgroundColor = .backgroundColor()

        imageView.image = Theme.Asset.icAlertProAccount.image
        titleLabel.textColor = .normalTextColor()
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        description1Label.textColor = .normalTextColor()
        description1Label.font = UIFont.systemFont(ofSize: 16)
        
        description2Label.textColor = .weakTextColor()
        description2Label.font = UIFont.systemFont(ofSize: 14)
        
        assignConnectionsButton.customState = .primary
        loginButton.customState = .secondary
    }
    
    // MARK: - Actions
    
    @IBAction private func assignConnectionsTapped() {
        safariServiceFactory?.makeSafariService().open(url: CoreAppConstants.ProtonVpnLinks.assignVPNConnections)
    }
    
    @IBAction private func loginTapped() {
        self.dismiss(animated: true, completion: {})
    }
}
