//
//  TrialWelcomeViewController.swift
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

class TrialWelcomeViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var secureCoreLabel: NSTextField!
    @IBOutlet weak var p2pLabel: NSTextField!
    @IBOutlet weak var connectionsLabel: NSTextField!
    @IBOutlet weak var countriesLabel: NSTextField!
    @IBOutlet weak var skipButton: ClearCancellationButton!
    @IBOutlet weak var takeTourButton: UpsellPrimaryActionButton!
    
    let navService: NavigationService
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(navService: NavigationService) {
        self.navService = navService
        super.init(nibName: NSNib.Name("TrialWelcome"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let title = NSMutableAttributedString(attributedString: String(format: LocalizedString.enjoyForFree, LocalizedString.plus).attributed(withColor: .protonWhite(), fontSize: 48, bold: true))
        let plusRange = (title.string as NSString).range(of: LocalizedString.plus)
        title.addAttribute(.foregroundColor, value: NSColor.protonUpsellGreen(), range: plusRange)
        titleLabel.attributedStringValue = title
        
        let description = NSMutableAttributedString(attributedString: String(format: LocalizedString.welcomeGiftDescription, LocalizedString.protonVpnPlus).attributed(withColor: .protonWhite(), fontSize: 20))
        let descriptionFullRange = (description.string as NSString).range(of: description.string)
        let descriptionPlusRange = (description.string as NSString).range(of: LocalizedString.protonVpnPlus)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6
        
        description.addAttribute(.paragraphStyle, value: paragraphStyle, range: descriptionFullRange)
        description.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 20), range: descriptionPlusRange)
        descriptionLabel.attributedStringValue = description
        
        secureCoreLabel.attributedStringValue = LocalizedString.secureCore.attributed(withColor: .protonWhite(), fontSize: 20)
        p2pLabel.attributedStringValue = LocalizedString.p2pServers.attributed(withColor: .protonWhite(), fontSize: 20)
        connectionsLabel.attributedStringValue = LocalizedString.connectionsAvailable.attributed(withColor: .protonWhite(), fontSize: 20)
        countriesLabel.attributedStringValue = LocalizedString.multipleCountries.attributed(withColor: .protonWhite(), fontSize: 20)
        
        skipButton.title = LocalizedString.skip
        takeTourButton.title = LocalizedString.takeTour
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyInfoAppearance()
    }
    
    @IBAction func skip(_ sender: Any) {
        dismiss(nil)
    }
    
    @IBAction func takeTour(_ sender: Any) {
        dismiss(nil)
        navService.presentGuidedTour()
    }
}
