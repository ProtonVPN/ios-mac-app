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

protocol ConnectToPlusServerViewControllerDelegate: AnyObject {
    func userDidRequestConnectToPlus()
    func userDidRequestSkipConnectToPlus()
}

final class ConnectToPlusServerViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private weak var noteLabel: UILabel!
    @IBOutlet private weak var skipButton: UIButton!

    // MARK: Properties

    weak var delegate: ConnectToPlusServerViewControllerDelegate?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(view)
        bigTitleStyle(titleLabel)
        centeredTextStyle(subtitleLabel)
        centeredTextStyle(noteLabel)
        actionButtonStyle(connectButton)
        textButtonStyle(skipButton)

        titleLabel.text = LocalizedString.onboardingCongratulations
        subtitleLabel.text = LocalizedString.onboardingPurchasedSubtitle
        noteLabel.text = LocalizedString.onboardingPurchasedNote
        connectButton.setTitle(LocalizedString.onboardingConnectedConnectToPlus, for: .normal)
        skipButton.setTitle(LocalizedString.onboardingSkip, for: .normal)

        skipButton.accessibilityIdentifier = "SkipButton"

        connectButton.accessibilityIdentifier = "ConnectToPlusServerButton"
    }

    // MARK: Actions

    @IBAction private func connectToPlusServerTapped(_ sender: Any) {
        delegate?.userDidRequestConnectToPlus()
    }

    @IBAction private func skipTapped(_ sender: Any) {
        delegate?.userDidRequestSkipConnectToPlus()
    }
}
