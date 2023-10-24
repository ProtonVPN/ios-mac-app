//
//  Created on 08/03/2022.
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
import Modals

final class DiscourageSecureCoreViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var dontShowAgainLabel: UILabel!
    @IBOutlet private weak var dontShowAgainSwitch: UISwitch!
    @IBOutlet private weak var featureView: UIView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var activateButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var learnMoreButton: UIButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var featureArtImageView: UIImageView!

    private let feature = DiscourageSecureCoreFeature()

    var onDontShowAgain: ((Bool) -> Void)?
    var onActivate: (() -> Void)?
    var onCancel: (() -> Void)?
    var onLearnMore: (() -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupOutlets()
        setupStrings()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let topInset = max(0, (scrollView.bounds.height - featureView.bounds.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    }

    private func setupOutlets() {
        view.backgroundColor = .color(.background)
        actionButtonStyle(activateButton)
        actionTextButtonStyle(cancelButton)
        titleStyle(titleLabel)
        subtitleStyle(subtitleLabel)
        actionTextButtonStyle(learnMoreButton)
        dontShowAgainSwitch.onTintColor = .color(.background, .interactive)

        dontShowAgainLabel.font = .systemFont(ofSize: 15, weight: .regular)
        dontShowAgainLabel.textColor = .color(.text)

        featureArtImageView.image = feature.artImage
    }

    private func setupStrings() {
        titleLabel.text = feature.title
        subtitleLabel.text = feature.subtitle
        learnMoreButton.setTitle(feature.learnMore, for: .normal)
        dontShowAgainLabel.text = feature.dontShow
        activateButton.setTitle(feature.activate, for: .normal)
        cancelButton.setTitle(feature.cancel, for: .normal)
    }

    @IBAction private func learnMoreButtonTapped(_ sender: UIButton) {
        onLearnMore?()
    }

    @IBAction private func dontShowAgainSwitchToggled(_ sender: UISwitch) {
        onDontShowAgain?(sender.isOn)
    }

    @IBAction private func activateButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onActivate?()
        })
    }

    @IBAction private func cancelButtonTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.onCancel?()
        })
    }
}
