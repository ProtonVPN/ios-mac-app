//
//  BatteryUsageViewController.swift
//  ProtonVPN - Created on 2020-09-04.
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

class BatteryUsageViewController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!
    private let textFontSize: CGFloat = 14
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupTranslations()
    }

    private func setupTranslations() {
        self.title = LocalizedString.batteryTitle
        descriptionLabel.text = LocalizedString.batteryDescription
        moreButton.setTitle(LocalizedString.batteryMore, for: .normal)
    }

    private func setupViews() {
        view.backgroundColor = .backgroundColor()
        
        descriptionLabel.font = UIFont.systemFont(ofSize: textFontSize)
        descriptionLabel.textColor = .normalTextColor()
        
        moreButton.tintColor = .brandColor()
        moreButton.titleLabel?.font = UIFont.systemFont(ofSize: textFontSize)
    }
    
    @IBAction func learMore() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.batteryOpenVpn)
    }

}
