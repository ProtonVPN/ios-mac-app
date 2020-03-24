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
    
    @IBOutlet var backgroundView: UIView!
    @IBOutlet var checkboxViewHolder: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var featuresLabel: UILabel!
    @IBOutlet var popularLabel: UILabel!
    @IBOutlet var priceLabel: UILabel!
    @IBOutlet var moreFeaturesButton: UIButton!
    @IBOutlet var moreFeaturesButtonConstraint: NSLayoutConstraint!
    @IBOutlet var mostPopularView: UIView!
    @IBOutlet var mostPopularLeftConstraint: NSLayoutConstraint!
    @IBOutlet var mostPopularRightConstraint: NSLayoutConstraint!
    @IBOutlet var mostPopularTopConstraint: NSLayoutConstraint!
    var checkboxView: RoundCheckboxView!
    @IBOutlet var priceTopConstraint: NSLayoutConstraint!
    @IBOutlet var priceBottomConstraint: NSLayoutConstraint!
    
    private var pricePrimarySize: CGFloat = 30.0
    private var priceSecondarySize: CGFloat = 18.0
    
    public var moreFeaturesSelected: ((AccountPlan) -> Void)?
    public var plan: AccountPlan! {
        didSet {
            fillViews()
        }
    }
    public var storeKitManager: StoreKitManager!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupRoundedCorners()
        
        titleLabel.textColor = .protonGreen()
        mostPopularView.backgroundColor = .protonGreen()
        moreFeaturesButton.tintColor = .protonGreen()
        
        if UIDevice.current.isSmallIphone { // iPhone 5s, SE
            priceTopConstraint.priority = .required
            setNeedsLayout()
        }
    }
    
    @IBAction func moreFeaturesPressed() {
        moreFeaturesSelected?(plan)
    }
    
    func setSelected(_ selected: Bool) {
        checkboxView.state = selected ? .on : .off
    }
    
    private func setupRoundedCorners() {
        backgroundView.backgroundColor = .protonGrey()
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 10
        
        self.layer.shadowRadius = 4
        self.layer.shadowOpacity = 0.67
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        mostPopularView.layer.masksToBounds = true
        mostPopularView.layer.cornerRadius = 3
    }
    
    private func fillViews() {
        titleLabel.text = plan.displayName
        
        if !plan.isMostPopular {
            mostPopularView.isHidden = true
            mostPopularLeftConstraint.isActive = false
            priceBottomConstraint.isActive = false
        } else {
            popularLabel.text = LocalizedString.mostPopular
        }
        
        if !plan.hasAdvancedFeatures {
            moreFeaturesButton.isHidden = true
            moreFeaturesButtonConstraint.isActive = false
        } else {
            moreFeaturesButton.setTitle(LocalizedString.advancedFeatures, for: .normal)
        }
        
        featuresLabel.text = "\(plan.countries)\n\(plan.devices)\n\(plan.speedDescription)"
        
        let priceAttributedText: NSAttributedString
        if let productId = plan.storeKitProductId, let price = storeKitManager.priceLabelForProduct(id: productId) {
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = price.1
            formatter.maximumFractionDigits = 2
            
            let total = price.0 as Decimal
            if var priceString = formatter.string(from: total as NSNumber) {
                priceString.append(LocalizedString.perYearShort)
                priceAttributedText = priceString.attributedCurrency(withNumberColor: .protonGreen(), numberFont: UIFont.boldSystemFont(ofSize: pricePrimarySize), withTextColor: .protonFontHeader(), textFont: UIFont.systemFont(ofSize: priceSecondarySize))
            } else {
                priceAttributedText = NSAttributedString(string: "")
            }
        } else if plan == .free || plan == .trial {
            priceAttributedText = LocalizedString.free.attributed(withColor: .protonGreen(), fontSize: pricePrimarySize, bold: true, alignment: .center)
        } else {
            priceAttributedText = LocalizedString.unavailable.attributed(withColor: .protonFontLightGrey(), fontSize: pricePrimarySize, alignment: .center)
        }
        priceLabel.attributedText = priceAttributedText
        
        checkboxView = RoundCheckboxView.loadViewFromNib() as RoundCheckboxView
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        checkboxViewHolder.addFillingSubview(checkboxView)
    }
    
    func checkWidth() {
        if plan.isMostPopular {
            let emptySpaceTop = self.frame.width - titleLabel.intrinsicContentSize.width - titleLabel.frame.origin.x - 18 - popularLabel.intrinsicContentSize.width
            if emptySpaceTop < 10 {
                mostPopularLeftConstraint.isActive = false
                mostPopularTopConstraint.isActive = false
                mostPopularRightConstraint.isActive = false
                setNeedsLayout()
            }
        }
        
        let emptySpace = self.frame.width - priceLabel.intrinsicContentSize.width - featuresLabel.intrinsicContentSize.width - featuresLabel.frame.origin.x - 18
        if emptySpace < 10 { 
            priceTopConstraint.priority = .required
            setNeedsLayout()
        }
    }
    
}
