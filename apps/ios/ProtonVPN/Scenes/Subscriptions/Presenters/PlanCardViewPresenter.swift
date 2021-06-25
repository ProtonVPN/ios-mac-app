//
//  PlanCardViewPresenter.swift
//  ProtonVPN - Created on 31/03/2020.
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

import Foundation
import vpncore
import UIKit

protocol PlanCardViewPresenter {
    
    var view: PlanCardView! { get set }
    var plan: AccountPlan! { get set }
    
    func setSelected( _ selected: Bool )
}

class PlanCardViewPresenterImplementation: PlanCardViewPresenter {

    weak var view: PlanCardView! {
        didSet {
            self.fillView()
        }
    }
    
    var storeKitManager: StoreKitManager!
    
    var plan: AccountPlan!

    var moreFeaturesSelected: ((AccountPlan) -> Void)?
    
    private let pricePrimarySize: CGFloat = 30.0
    private let priceSecondarySize: CGFloat = 18.0
    private let serversManager: ServerManager
    private let featuresLabelOriginalSize: CGSize = .zero
    
    init( _ plan: AccountPlan, storeKitManager: StoreKitManager, serversManager: ServerManager, moreFeaturesSelected: ((AccountPlan) -> Void)? = nil ) {
        self.plan = plan
        self.storeKitManager = storeKitManager
        self.moreFeaturesSelected = moreFeaturesSelected
        self.serversManager = serversManager
    }
    
    func setSelected(_ selected: Bool) {
        view.checkboxView.state = selected ? .on : .off
    }
    
    // MARK: - Private
    // swiftlint:disable function_body_length

    private func fillView() {
        view.titleLabel.text = plan.displayName
        view.moreFeaturesButton.addTarget(self, action: #selector(didTapMoreFeatures), for: .touchUpInside)
        view.moreFeaturesButton.isHidden = !plan.hasAdvancedFeatures
        view.bottomSeparatorView.isHidden = !plan.hasAdvancedFeatures
    
        var totalCountries = 0
        let totalConnections = plan.devicesCount
        
        switch plan {
        case .free:
            totalCountries = serversManager.grouping(for: .standard).filter { $0.0.lowestTier == 0 }.count
        default:
            totalCountries = serversManager.grouping(for: .standard).count
        }
        
        let featuresText = "\(LocalizedString.countriesCount(totalCountries))\n\(LocalizedString.plansConnections(totalConnections))\n\(plan.speedDescription)\n\(LocalizedString.adblockerNetshieldFeature)"
        let attributedFeaturesText = NSMutableAttributedString(string: featuresText)
        let range: NSRange = NSRange(location: featuresText.count - LocalizedString.adblockerNetshieldFeature.count, length: LocalizedString.adblockerNetshieldFeature.count)
        if plan == .free { attributedFeaturesText.addAttributes( [NSAttributedString.Key.strikethroughStyle: 1], range: range) }
        view.featuresLabel.attributedText = attributedFeaturesText
        view.featuresLabel.textAlignment = .natural
        view.mostPopularContainerView.isHidden = !plan.isMostPopular
                
        guard let productId = plan.storeKitProductId, let price = storeKitManager.priceLabelForProduct(id: productId) else {
            var text = LocalizedString.unavailable
            var textColor = UIColor.protonFontLightGrey()

            if [.free, .trial].contains(plan) {
                text = LocalizedString.free
                textColor = .protonGreen()
            }
            view.priceLabel.attributedText = text.attributed(withColor: textColor, fontSize: pricePrimarySize, bold: true, alignment: .center)
            organizeLayout()
            return
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = price.1
        formatter.maximumFractionDigits = 2
        
        let total = price.0 as Decimal
        if var priceString = formatter.string(from: total as NSNumber) {
            let numberFont = UIFont.boldSystemFont(ofSize: pricePrimarySize)
            let textFont = UIFont.systemFont(ofSize: priceSecondarySize)
            priceString.append(LocalizedString.perYearShort)
            view.priceLabel.attributedText = priceString
                .attributedCurrency(withNumberColor: .protonGreen(), numberFont: numberFont, withTextColor: .protonFontHeader(), textFont: textFont )
        } else {
            view.priceLabel.attributedText = NSAttributedString(string: "")
        }
        
        organizeLayout()
    }
    
    // swiftlint:enable function_body_length
    
    private func organizeLayout() {
        
        // Because of the stackview at this point we don't have a real size
        // a new label has to be created with the same configuration to get a real size
        
        let featuresSize = view.featuresLabel.realSize

        // If the size exceds a 30% of the screen it should be splited in two rows
        
        let featuresThreshold = UIScreen.main.bounds.width * 0.3
        
        if featuresSize.width > featuresThreshold {
            view.priceStackView.axis = .vertical
            view.priceLabel.textAlignment = .right
        }
        
        guard plan.isMostPopular else {
            return // If it is not a popular plan we don't bother on checking its real size
        }
        
        let titleWidth = view.titleLabel.realSize.width + view.titleLabel.frame.origin.x
        let popularSize = view.popularLabel.realSize.width + view.mostPopularTrailingConstant.constant * view.mostPopularTrailingConstant.multiplier
        let widthThreshold = UIScreen.main.bounds.width * 0.98
        
        guard titleWidth + popularSize > widthThreshold else {
            return // Title and "Most popular" fit nicely, no need to split
        }

        view.titleStackView.axis = .vertical
        view.mostPopularTrailingConstant.isActive = false
        view.mostPopularSeparatorView.isHidden = true

    }
    
    @objc private func didTapMoreFeatures() {
        moreFeaturesSelected?(plan)
    }
}
