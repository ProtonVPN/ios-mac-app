//
//  WelcomeViewController.swift
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

class WelcomeViewController: NSViewController {
    
    @IBOutlet weak var mapView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var noThanksButton: NSButton!
    @IBOutlet weak var takeTourButton: UpsellPrimaryActionButton!
    
    let navService: NavigationService
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(navService: NavigationService) {
        self.navService = navService
        super.init(nibName: NSNib.Name("Welcome"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonMapGrey().cgColor
        
        if let mapImage = mapView.image {
            mapView.image = mapImage.colored(.protonMapBackgroundGrey())
        }
        
        titleLabel.attributedStringValue = LocalizedString.welcomeTitle.attributed(withColor: .protonWhite(), fontSize: 48, bold: true)
        
        let description = NSMutableAttributedString(attributedString: LocalizedString.welcomeDescription.attributed(withColor: .protonWhite(), fontSize: 20))
        let fullRange = (description.string as NSString).range(of: description.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6
        
        description.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        descriptionLabel.attributedStringValue = description
        
        noThanksButton.title = LocalizedString.noThanks
        takeTourButton.title = LocalizedString.takeTour
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyInfoAppearance()
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(nil)
    }
    
    @IBAction func takeTour(_ sender: Any) {
        dismiss(nil)
        navService.presentGuidedTour()
    }
}
