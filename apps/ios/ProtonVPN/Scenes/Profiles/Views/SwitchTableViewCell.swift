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

import UIKit
import LegacyCommon
import Theme

final class SwitchTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var switchControl: ConfirmationToggleSwitch!
    @IBOutlet weak var upsellImageView: UIImageView!

    var upsellTapped: (() -> Void)?
    var toggled: ((Bool, @escaping (Bool) -> Void) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.isSelected = false

        backgroundColor = .secondaryBackgroundColor()
        label.textColor = .normalTextColor()
        selectionStyle = .none

        upsellImageView.image = Theme.Asset.vpnSubscriptionBadge.image
        upsellImageView.isHidden = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(upsellImageViewTapped))
        upsellImageView.isUserInteractionEnabled = true
        upsellImageView.addGestureRecognizer(tapRecognizer)

        let update = { (on: Bool) -> Void in
            self.switchControl.setOn(on, animated: true)
        }

        switchControl.tapped = { [unowned self] in
            self.toggled?(!self.switchControl.isOn, update)
        }
    }

    @IBAction func upsellImageViewTapped(_ sender: Any) {
        guard let upsellTapped else {
            log.error("Upsell tapped but no upsell action has defined for this element")
            return
        }
        upsellTapped()
    }

    func setup(with model: PaidFeatureDisplayState) {
        switch model {
        case .disabled:
            log.assertionFailure("We shouldn't display cells for disabled features")
            // We shouldn't be showing UI for a feature that has been disabled, so just fall back to showing upsell
            fallthrough
        case .upsell:
            switchControl.isHidden = true
            upsellImageView.isHidden = false

        case .available(let isOn, let isInterative):
            switchControl.isHidden = false
            upsellImageView.isHidden = true

            switchControl.isEnabled = isInterative
            switchControl.isOn = isOn
        }
    }
}
