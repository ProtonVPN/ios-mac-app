//
//  UpsellStandardTableViewCell.swift
//  ProtonVPN - Created on 28.05.25.
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

import LegacyCommon
import Strings
import Theme
import UIKit

final class UpsellStandardTableViewCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet private var iconContainer: UIView!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var upsellImageView: UIImageView!

    var completionHandler: (() -> Void)?
    var upsellTapped: (() -> Void)?

    private var canSelect: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
            iconContainer.isHidden = icon == nil
        }
    }

    func select() {
        guard canSelect else { return }
        completionHandler?()
    }

    func invert() {
        setupViews(inverted: true)
    }

    func setupViews(inverted: Bool = false, icon: UIImage? = nil) {
        backgroundColor = .secondaryBackgroundColor()

        titleLabel.font = UIFont.systemFont(ofSize: 17)
        subtitleLabel.font = UIFont.systemFont(ofSize: 17)

        self.icon = icon
        if !inverted {
            titleLabel.textColor = .normalTextColor()
            subtitleLabel.textColor = .weakTextColor()
        } else {
            titleLabel.textColor = .weakTextColor()
            subtitleLabel.textColor = .normalTextColor()
        }

        upsellImageView.image = Theme.Asset.vpnSubscriptionBadge.image
        upsellImageView.isHidden = true
        upsellImageView.isAccessibilityElement = true
        upsellImageView.accessibilityValue = Localizable.vpnPlusUpsellAccessibility

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(upsellImageViewTapped))
        upsellImageView.isUserInteractionEnabled = true
        upsellImageView.addGestureRecognizer(tapRecognizer)
    }

    func setup(with model: PaidFeatureDisplayState) {
        switch model {
        case .disabled:
            log.assertionFailure("We shouldn't display cells for disabled features")
            // We shouldn't be showing UI for a feature that has been disabled, so just fall back to showing upsell
            fallthrough

        case .upsell:
            accessoryType = .none
            subtitleLabel.isHidden = true
            upsellImageView.isHidden = false
            canSelect = false

        case .available:
            accessoryType = .disclosureIndicator
            subtitleLabel.isHidden = false
            upsellImageView.isHidden = true
            canSelect = true
        }
    }
}

private extension UpsellStandardTableViewCell {
    @IBAction
    private func upsellImageViewTapped(_: Any) {
        guard let upsellTapped else {
            log.error("Upsell tapped but no upsell action has defined for this element")
            return
        }
        upsellTapped()
    }
}
