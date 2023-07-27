//
//  FeatureTableViewCell.swift
//  ProtonVPN - Created on 21.04.21.
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
import LegacyCommon
import ProtonCoreUIFoundations
import Strings

class FeatureTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var iconIV: UIImageView!
    @IBOutlet private weak var titleLbl: UILabel!
    @IBOutlet private weak var descriptionLbl: UILabel!
    @IBOutlet private weak var learnMoreBtn: UIButton!
    
    @IBOutlet weak var loadViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var loadView: UIView!
    @IBOutlet private weak var loadLowView: UIView!
    @IBOutlet private weak var loadLowLbl: UILabel!
    @IBOutlet private weak var loadMediumView: UIView!
    @IBOutlet private weak var loadMediumLbl: UILabel!
    @IBOutlet private weak var loadHighView: UIView!
    @IBOutlet private weak var loadHighLbl: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .backgroundColor()
        learnMoreBtn.setTitleColor(UIColor.textAccent(), for: .normal)
        learnMoreBtn.tintColor = UIColor.textAccent()
        learnMoreBtn.setImage(IconProvider.arrowOutSquare, for: .normal)
    }
    
    var viewModel: FeatureCellViewModel! {
        didSet {
            titleLbl.text = viewModel.title
            switch viewModel.icon {
            case .image(let image):
                iconIV.image = image
            case .url(let url):
                if let url {
                    iconIV.af.setImage(withURL: url)
                }
            }

            descriptionLbl.text = viewModel.description
            learnMoreBtn.setTitle(Localizable.learnMore, for: .normal)
            
            if viewModel.displayLoads {
                loadView.isHidden = false
                loadViewHeightConstraint.constant = 32
                loadLowLbl.text = Localizable.performanceLoadLow
                loadLowView.backgroundColor = .notificationOKColor()
                loadMediumLbl.text = Localizable.performanceLoadMedium
                loadMediumView.backgroundColor = .notificationWarningColor()
                loadHighLbl.text = Localizable.performanceLoadHigh
                loadHighView.backgroundColor = .notificationErrorColor()
            } else {
                loadView.isHidden = true
                loadViewHeightConstraint.constant = 0
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction private func didTapLearnMore(_ sender: Any) {
        guard let urlContact = viewModel.urlContact else { return }
        SafariService().open(url: urlContact)
    }
}
