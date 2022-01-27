//
//  Created on 10.01.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import UIKit

protocol UpsellViewControllerDelegate: AnyObject {
    func userDidRequestPlus()
    func userDidDismissUpsell()
}

final class UpsellViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var getPlusButton: UIButton!
    @IBOutlet private weak var useFreeButton: UIButton!
    @IBOutlet private weak var featuresStackView: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var featuresFooterLabel: UILabel!

    // MARK: Properties

    weak var delegate: UpsellViewControllerDelegate?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(view)
        actionButtonStyle(getPlusButton)
        actionTextButtonStyle(useFreeButton)
        titleStyle(titleLabel)
        footerStyle(featuresFooterLabel)

        getPlusButton.setTitle(LocalizedString.onboardingGetPlus, for: .normal)
        useFreeButton.setTitle(LocalizedString.onboardingUpsellStayFree, for: .normal)
        titleLabel.text = LocalizedString.onboardingUpsellTitle
        featuresFooterLabel.text = LocalizedString.onboardingUpsellFeaturesFooter

        useFreeButton.accessibilityLabel = "UseFreeButton"
        getPlusButton.accessibilityLabel = "GetPlusButton"

        let closeButton = UIBarButtonItem(image: UIImage(named: "CloseButton", in: Bundle.module, compatibleWith: nil), style: .plain, target: self, action: #selector(closeTapped))
        closeButton.accessibilityLabel = "CloseButton"
        navigationItem.leftBarButtonItem = closeButton

        for view in featuresStackView.arrangedSubviews {
            view.removeFromSuperview()
            featuresStackView.removeArrangedSubview(view)
        }

        for feature in Feature.allCases {
            let view = Bundle.module.loadNibNamed("FeatureView", owner: self, options: nil)?.first as! FeatureView
            view.feature = feature
            featuresStackView.addArrangedSubview(view)
        }
    }

    // MARK: Actions

    @IBAction private func getPlusTapped(_ sender: Any) {
        delegate?.userDidRequestPlus()
    }

    @IBAction private func useFreeTapped(_ sender: Any) {
        delegate?.userDidDismissUpsell()
    }

    @objc private func closeTapped() {
        delegate?.userDidDismissUpsell()
    }
}
