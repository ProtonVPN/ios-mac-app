//
//  Created on 07/07/2022.
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

import Modals
import UIKit

public final class InformativeViewController: UIViewController {

    var viewModel = InformativeViewModel()

    var onPrimaryButtonTap: (() -> Void)?

    @IBOutlet weak var scrollView: CenteringScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var primaryButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFeature()
    }

    private func setupUI() {
        baseViewStyle(view)
        actionButtonStyle(primaryButton)
        titleStyle(titleLabel)
        subtitleStyle(descriptionLabel)

        setIsLoading(true)

        primaryButton.accessibilityIdentifier = "primaryButton"
        titleLabel.accessibilityIdentifier = "TitleLabel"
    }

    public func setIsLoading(_ isLoading: Bool) {
        primaryButton.isHidden = isLoading
        stackView.isHidden = isLoading
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func setupFeature() {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
        imageView.image = viewModel.image
        primaryButton.setTitle(viewModel.acknowledgeButtonTitle, for: .normal)
    }

    @IBAction func acknowledgmentTapped(_ sender: UIButton) {
        onPrimaryButtonTap?()
    }
}
