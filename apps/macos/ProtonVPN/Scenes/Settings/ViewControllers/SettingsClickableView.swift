//
//  Created on 2025-04-04 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import AppKit
import LegacyCommon
import Theme

protocol ClickableViewDelegate: AnyObject {
    func tapped(_ view: SettingsClickableView)
}

class SettingsClickableView: NSView {

    struct ViewModel {
        let labelText: String
        let state: PaidFeatureDisplayState

        enum State {
            case chevron
            case upsell
        }
    }

    private weak var delegate: ClickableViewDelegate?

    @IBOutlet private weak var label: PVPNTextField!
    @IBOutlet private weak var upsellImageView: HoverableButtonImageView?
    @IBOutlet private weak var separator: NSBox!

    private var model: ViewModel?

    override func accessibilityRole() -> NSAccessibility.Role? {
        .disclosureTriangle
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseUp(with event: NSEvent) {
        guard frame.contains(event.locationInWindow) else { return }
        delegate?.tapped(self)
    }

    func setupItem(model: ViewModel, delegate: ClickableViewDelegate?) {
        self.delegate = delegate
        self.model = model

        label.attributedStringValue = model.labelText.styled(font: .themeFont(.heading4), alignment: .left)

        separator.fillColor = .color(.border, .weak)

        switch model.state {
        case .disabled:
            log.warning("Feature is disabled, we shouldn't be showing a view for its state")
            log.assertionFailure("Disabled features shouldn't be shown")
            fallthrough // show upsell instead
        case .upsell:
            guard let upsellImageView else {
                log.assertionFailure("Upsellable features must link to an upsell image view")
                return
            }
            upsellImageView.imageClicked = { [weak self] in self?.upsellImageViewTapped() }

            upsellImageView.image = Theme.Asset.vpnSubscriptionBadge.image
            upsellImageView.isHidden = false

        case .available(let isOn, _):
            upsellImageView?.isHidden = true
        }
    }

    private func upsellImageViewTapped() {
        delegate?.tapped(self)
    }
}
