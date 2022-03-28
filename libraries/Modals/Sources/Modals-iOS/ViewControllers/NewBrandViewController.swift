//
//  Created on 28/03/2022.
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

class NewBrandViewController: UIViewController {

    @IBOutlet private weak var iconBackground: UIImageView!
    @IBOutlet private weak var newBrandBackground: UIImageView!
    @IBOutlet private weak var newBrandBackgroundHeight: NSLayoutConstraint!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var readMoreButton: UIButton!
    @IBOutlet private weak var dismissButton: UIButton!
    @IBOutlet private weak var contentView: UIView!

    var onDismiss: (() -> Void)?
    var onReadMore: (() -> Void)?

    let feature = NewBrandFeature()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: 0.52)

        newBrandBackground.image = feature.artImage
        newBrandBackground.layer.cornerRadius = 8
        iconBackground.image = feature.iconImage

        titleLabel.text = feature.title
        subtitleLabel.text = feature.subtitle
        readMoreButton.setTitle(feature.learnMore, for: .normal)
        dismissButton.setTitle(feature.cancel, for: .normal)

        contentView.layer.cornerRadius = 8

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = colors.text
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = colors.weakText

        actionButtonStyle(readMoreButton)
        actionTextButtonStyle(dismissButton)

        contentView.backgroundColor = colors.background
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = feature.artImage.size
        newBrandBackgroundHeight.constant = contentView.bounds.size.width * (size.height / size.width)
    }

    @IBAction private func readMoreButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onReadMore?()
        })
    }

    @IBAction private func dismissButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onDismiss?()
        })
    }
}
