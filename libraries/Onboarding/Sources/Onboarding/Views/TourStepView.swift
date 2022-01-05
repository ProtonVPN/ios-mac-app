//
//  Created on 04.01.2022.
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

import UIKit

final class TourStepView: UIView {

    // MARK: Outlets

    @IBOutlet private weak var topView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var plusOnlyView: UIView!
    @IBOutlet private weak var plusOnlyLabel: UILabel!
    @IBOutlet private weak var pageControlView: UIPageControl!

    // MARK: Properties

    var step: TourStep? {
        didSet {
            guard let step = step else {
                return
            }

            imageView.image = step.image
            pageControlView.currentPage = TourStep.allCases.firstIndex(of: step) ?? 0
            titleLabel.text = step.title
            subtitleLabel.text = step.subtitle
        }
    }

    // MARK: Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(self)
        tourStepHeaderStyle(topView)
        tourPagerStyle(pageControlView)
        centeredTextStyle(subtitleLabel)
        titleStyle(titleLabel)
        plusOnlyStyle(plusOnlyView)
        plusOnlyTextStyle(plusOnlyLabel)

        plusOnlyLabel.text = LocalizedString.onboardingPlusOnly.uppercased()
    }
}
