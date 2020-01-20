//
//  SCUpgradePopupViewController.swift
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

class SCUpgradePopupViewController: NSViewController {
    
    @IBOutlet weak var bodyView: NSView!
    @IBOutlet weak var upgradeIcon: NSImageView!
    @IBOutlet weak var upgradeDescriptionPart1: NSTextField!
    @IBOutlet weak var learnMoreButton: GreenActionButton!
    @IBOutlet weak var upgradeDescriptionPart2: NSTextField!
    
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var cancelButton: WhiteCancelationButton!
    @IBOutlet weak var upgradeButton: PrimaryActionButton!
    
    let viewModel: SCUpgradePopUpViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: SCUpgradePopUpViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: NSNib.Name("SCUpgradePopup"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBodyView()
        setupFooterView()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.applyWarningAppearance(withTitle: LocalizedString.upgradeRequired)
    }
    
    private func setupBodyView() {
        bodyView.wantsLayer = true
        bodyView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        
        upgradeIcon.image = #imageLiteral(resourceName: "temp")
        
        upgradeDescriptionPart1.attributedStringValue =
            LocalizedString.upgradePlanToAccessSecureCore1.attributed(withColor: .protonWhite(), fontSize: 14, alignment: .left)

        learnMoreButton.title = LocalizedString.learnMoreAboutSecureCore
        learnMoreButton.alignment = .left
        learnMoreButton.target = self
        learnMoreButton.action = #selector(learnMoreButtonAction)
        
        upgradeDescriptionPart2.attributedStringValue =
            LocalizedString.upgradePlanToAccessSecureCore2.attributed(withColor: .protonWhite(), fontSize: 14, alignment: .left)
    }
    
    private func setupFooterView() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        
        cancelButton.title = LocalizedString.cancel
        cancelButton.fontSize = 14
        cancelButton.target = self
        cancelButton.action = #selector(okButtonAction)
        
        upgradeButton.title = LocalizedString.upgrade
        upgradeButton.fontSize = 14
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradeButtonAction)
    }
    
    @objc private func learnMoreButtonAction() {
        viewModel.learnMoreAction()
    }
    
    @objc private func okButtonAction() {
        viewModel.cancelAction()
        dismiss(nil)
    }
    
    @objc private func upgradeButtonAction() {
        viewModel.upgradeAction()
        dismiss(nil)
    }
}
