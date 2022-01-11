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

import Foundation
import UIKit

protocol ConnectedViewControllerDelegate: AnyObject {
    func userDidFinish()
}

final class ConnectedViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var doneButton: UIButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var noteLabel: UILabel!
    @IBOutlet private weak var countryView: UIView!
    @IBOutlet private weak var connectedToLabel: UILabel!
    @IBOutlet private weak var countryLabel: UILabel!
    @IBOutlet private weak var countryImage: UIImageView!

    // MARK: Properties

    weak var delegate: ConnectedViewControllerDelegate?

    var country: Country? {
        didSet {
            guard isViewLoaded else {
                return
            }

            setupCountry()
        }
    }

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(view)
        actionButtonStyle(doneButton)
        bigTitleStyle(titleLabel)
        centeredTextStyle(subtitleLabel)
        centeredTextStyle(noteLabel)
        textSubNoteStyle(connectedToLabel)
        countryTextStyle(countryLabel)
        countryViewStyle(countryView)

        titleLabel.text = LocalizedString.onboardingConnectedTitle
        connectedToLabel.text = LocalizedString.onboardingConnectedConnectedTo

        setupCountry()
    }

    private func setupCountry() {
        countryView.isHidden = country == nil
        countryLabel.text = country?.name
        countryImage.image = country?.flag

        subtitleLabel.text = country == nil ? LocalizedString.onboardingNotConnectedSubtitle : LocalizedString.onboardingConnectedSubtitle
        noteLabel.text = country == nil ? nil : LocalizedString.onboardingConnectedNote
    }

    // MARK: Actions

    @IBAction private func doneTapped(_ sender: Any) {
        delegate?.userDidFinish()
    }
}
