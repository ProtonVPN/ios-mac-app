//
//  UpgradeAdvertViewController.swift
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

final class UpsellViewController: NSViewController {

    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var descriptionLabel: NSTextField!
    @IBOutlet private weak var upgradeButton: UpsellPrimaryActionButton!
    @IBOutlet private weak var skipButton: GreenActionButton!
    @IBOutlet private weak var moneyBackGuarantee: NSTextField!
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(nibName: NSNib.Name("Upsell"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.attributedStringValue = LocalizedString.plusUpgradeTitle.attributed(withColor: .protonWhite(), fontSize: 48, bold: true, alignment: .left)
        
        let description = NSMutableAttributedString(attributedString: LocalizedString.plusUpgradeDescription.attributed(withColor: .protonWhite(), fontSize: 20))
        let descriptionFullRange = (description.string as NSString).range(of: description.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 6
        
        description.addAttribute(.paragraphStyle, value: paragraphStyle, range: descriptionFullRange)
        descriptionLabel.attributedStringValue = description
        
        upgradeButton.title = LocalizedString.upgradeMyPlan
        skipButton.title = LocalizedString.maybeLater
        skipButton.fontSize = 15
        
        moneyBackGuarantee.attributedStringValue = LocalizedString.moneyBackGuarantee.attributed(withColor: .protonWhite(), fontSize: 12)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyInfoAppearance()
    }
    
    @IBAction private func upgrade(_ sender: Any) {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
        dismiss(nil)
    }
    
    @IBAction private func cancel(_ sender: Any) {
        dismiss(nil)
    }
}
