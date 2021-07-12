//
//  DataDisclaimer.swift
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

class DataDisclaimerViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet var agreeButton: ProtonButton!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(nibName: "DataDisclaimer", bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .protonBlack()
        let disclaimer = NSMutableAttributedString(attributedString: "\(LocalizedString.dataDisclaimerTitle)\n\n\n\(LocalizedString.dataDisclaimerText(LocalizedString.dataDisclaimerUserDetails, LocalizedString.dataDisclaimerDeviceDetails))".attributed(withColor: .protonFontLightGrey(), fontSize: 16, alignment: .left))
        let fullRange = (disclaimer.string as NSString).range(of: disclaimer.string)
        let titleRange = (disclaimer.string as NSString).range(of: LocalizedString.dataDisclaimerTitle)
        let userRange = (disclaimer.string as NSString).range(of: LocalizedString.dataDisclaimerUserDetails)
        let deviceRange = (disclaimer.string as NSString).range(of: LocalizedString.dataDisclaimerDeviceDetails)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 2
        disclaimer.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        disclaimer.addAttribute(.font, value: UIFont.systemFont(ofSize: 30), range: titleRange)
        disclaimer.addAttribute(.foregroundColor, value: UIColor.protonGreen(), range: titleRange)
        disclaimer.addAttribute(.foregroundColor, value: UIColor.protonWhite(), range: userRange)
        disclaimer.addAttribute(.foregroundColor, value: UIColor.protonWhite(), range: deviceRange)
        textView.attributedText = disclaimer
        textView.contentOffset = CGPoint.zero
        textView.showsVerticalScrollIndicator = false
        agreeButton.setTitle(LocalizedString.dataDisclaimerAgree, for: .normal)
        agreeButton.accessibilityIdentifier = "Agree & Continue"
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        textView.contentOffset = CGPoint.zero
    }
    
    @IBAction func agreeTapped(_ sender: Any) {
        PropertiesManager().userDataDisclaimerAgreed = true
        dismiss(animated: true, completion: nil)
    }
}
