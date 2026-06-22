//
//  SwitchTableViewCell.swift
//  ProtonVPN - Created on 01.07.19.
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
import VPNAppCore

final class SwitchTableViewCell: UITableViewCell {
    @IBOutlet var label: UILabel!
    @IBOutlet var switchControl: ConfirmationToggleSwitch!
    @IBOutlet var upsellImageView: UIImageView!

    var upsellTapped: (() -> Void)?
    var toggled: ((Bool, @escaping (Bool) -> Void) -> Void)?

    /// Spinner shown to the left of the switch while a feature change is being applied by the extension
    private lazy var applyingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        contentView.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -12),
            indicator.centerYAnchor.constraint(equalTo: switchControl.centerYAnchor),
        ])
        return indicator
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        isSelected = false

        backgroundColor = .secondaryBackgroundColor()
        label.textColor = .normalTextColor()
        selectionStyle = .none

        upsellImageView.image = Theme.Asset.vpnSubscriptionBadge.image
        upsellImageView.isHidden = true
        upsellImageView.isAccessibilityElement = true
        upsellImageView.accessibilityValue = Localizable.vpnPlusUpsellAccessibility

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(upsellImageViewTapped))
        upsellImageView.isUserInteractionEnabled = true
        upsellImageView.addGestureRecognizer(tapRecognizer)

        let update = { on in
            self.switchControl.setOn(on, animated: true)
        }

        switchControl.tapped = { [unowned self] in
            toggled?(!switchControl.isOn, update)
        }
    }

    @IBAction
    func upsellImageViewTapped(_: Any) {
        guard let upsellTapped else {
            log.error("Upsell tapped but no upsell action has defined for this element")
            return
        }
        upsellTapped()
    }

    func setup(with model: PaidFeatureDisplayState, isOverridden: Bool? = nil, isApplying: Bool = false) {
        switch model {
        case .disabled:
            log.assertionFailure("We shouldn't display cells for disabled features")
            // We shouldn't be showing UI for a feature that has been disabled, so just fall back to showing upsell
            fallthrough

        case .upsell:
            applyingIndicator.stopAnimating()
            switchControl.isHidden = true
            upsellImageView.isHidden = false

        case let .available(isOn, isInterative):
            upsellImageView.isHidden = true
            switchControl.isHidden = false

            if isApplying {
                // Keep the switch at the value the user chose, dimmed + non-interactive, until the server acks with the
                // applied value.
                switchControl.isOn = isOn
                switchControl.onTintColor = .brandColor()
                switchControl.isEnabled = true
                switchControl.isUserInteractionEnabled = false
                switchControl.alpha = 0.5
                applyingIndicator.startAnimating()
            } else {
                applyingIndicator.stopAnimating()
                switchControl.isUserInteractionEnabled = true
                switchControl.alpha = 1
                switchControl.isEnabled = isInterative
                if let isOverridden {
                    switchControl.isOn = isOverridden
                    switchControl.onTintColor = .iconWeak()
                } else {
                    switchControl.isOn = isOn
                    switchControl.onTintColor = .brandColor()
                }
            }
        }
    }
}
