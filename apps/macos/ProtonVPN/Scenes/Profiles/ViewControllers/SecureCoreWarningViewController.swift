//
//  SecureCoreWarningViewController.swift
//  ProtonVPN - Created on 27.06.19.
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

final class SecureCoreWarningViewController: NSViewController {
    
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var upgradeButton: PrimaryActionButton!
    @IBOutlet weak var learnMoreButton: InteractiveActionButton!

    private let sessionService: SessionService
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(sessionService: SessionService) {
        self.sessionService = sessionService
        super.init(nibName: NSNib.Name("SecureCoreWarning"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupComponents()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.applyModalAppearance(withTitle: LocalizedString.upgradeRequired)
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .cgColor(.background, .weak)
    }
    
    private func setupComponents() {
        descriptionLabel.usesSingleLineMode = false
        descriptionLabel.cell?.lineBreakMode = .byWordWrapping
        descriptionLabel.attributedStringValue = LocalizedString.planDoesNotIncludeSecureCore.styled(font: .themeFont(.heading4, bold: true))
        
        upgradeButton.title = LocalizedString.upgradeRequired
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradeButtonAction)
        
        learnMoreButton.title = LocalizedString.learnMoreAboutSecureCore
        learnMoreButton.target = self
        learnMoreButton.action = #selector(learnMoreButtonAction)
    }
    
    @objc private func upgradeButtonAction() {
        sessionService.getUpgradePlanSession { url in
            SafariService.openLink(url: url)
        }
        dismiss(nil)
    }
    
    @objc private func learnMoreButtonAction() {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.learnMore)
        dismiss(nil)
    }
}
