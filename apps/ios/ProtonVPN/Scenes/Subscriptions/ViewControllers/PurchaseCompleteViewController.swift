//
//  PurchaseCompleteViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import vpncore

class PurchaseCompleteViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var doneButton: ProtonButton!
    
    var plan: AccountPlan?
    var navigationService: NavigationService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
    }
    
    private func setupView() {
        titleLabel.attributedText = LocalizedString.setupComplete.attributed(withColor: .protonGreen(), fontSize: 24, alignment: .center)
        
        if let plan = plan {
            let planText: String
            switch plan {
            case .free, .trial:
                planText = LocalizedString.setupCompleteFree
            case .basic:
                planText = LocalizedString.setupCompleteBasic
            case .plus:
                planText = LocalizedString.setupCompletePlus
            default:
                planText = ""
            }
            
            let descriptionAttributedText = NSMutableAttributedString(attributedString: planText.attributed(withColor: .protonWhite(), fontSize: 18, alignment: .center))
            let fullRange = (planText as NSString).range(of: planText)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 5
            descriptionAttributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            descriptionLabel.attributedText = descriptionAttributedText
        }
        
        doneButton.setTitle(LocalizedString.done, for: .normal)
    }
    
    // MARK: User actions
    @IBAction func doneButtonTapped(_ sender: Any) {
        navigationService?.presentMainInterface()
        dismiss(animated: true, completion: nil)
    }
}
