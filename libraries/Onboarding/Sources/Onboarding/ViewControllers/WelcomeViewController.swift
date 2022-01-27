//
//  Created on 03.01.2022.
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

protocol WelcomeViewControllerDelegate: AnyObject {
    func userDidRequestTakeTour()
    func userDidRequestSkipTour()
}

final class WelcomeViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var skipButton: UIButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    // MARK: Properties

    weak var delegate: WelcomeViewControllerDelegate?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        actionButton.setTitle(LocalizedString.onboardingTakeTour, for: .normal)
        skipButton.setTitle(LocalizedString.onboardingSkip, for: .normal)
        titleLabel.text = LocalizedString.onboardingWelcomeTitle
        subtitleLabel.text = LocalizedString.onboardingWelcomeSubtitle

        skipButton.accessibilityLabel = "SkipButton"

        baseViewStyle(view)
        actionButtonStyle(actionButton)
        textButtonStyle(skipButton)
        centeredTextStyle(subtitleLabel)
        bigTitleStyle(titleLabel)
    }

    // MARK: Actions

    @IBAction private func skipTapped(_ sender: Any) {
        delegate?.userDidRequestSkipTour()
    }

    @IBAction private func takeTourTapped(_ sender: Any) {
        delegate?.userDidRequestTakeTour()
    }
}
