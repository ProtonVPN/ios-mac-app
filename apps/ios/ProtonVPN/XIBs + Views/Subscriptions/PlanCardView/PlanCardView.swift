//
//  PlanCardView.swift
//  ProtonVPN - Created on 30/08/2019.
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

class PlanCardView: UIView {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var checkboxViewHolder: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var featuresLabel: UILabel!
    @IBOutlet weak var popularLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var moreFeaturesButton: UIButton!
    @IBOutlet weak var mostPopularView: UIView!
    @IBOutlet weak var mostPopularContainerView: UIView!
    @IBOutlet weak var mostPopularTrailingConstant: NSLayoutConstraint!
    @IBOutlet weak var mostPopularSeparatorView: UIView!
    @IBOutlet weak var bottomSeparatorView: UIView!
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var priceStackView: UIStackView!
    
    weak var checkboxView: RoundCheckboxView!

    var presenter: PlanCardViewPresenter! {
        didSet {
            self.presenter.view = self
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundView.backgroundColor = .protonGrey()
        mostPopularView.backgroundColor = .protonGreen()
        
        popularLabel.text = LocalizedString.mostPopular
        titleLabel.textColor = .protonGreen()
        moreFeaturesButton.tintColor = .protonGreen()
        moreFeaturesButton.setTitle(LocalizedString.advancedFeatures, for: .normal)
        
        let checkboxView = RoundCheckboxView.loadViewFromNib() as RoundCheckboxView
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        checkboxViewHolder.addFillingSubview(checkboxView)
        self.checkboxView = checkboxView
    }
    
    func setSelected(_ selected: Bool) {
        presenter.setSelected(selected)
    }
}
