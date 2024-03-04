//
//  Created on 01/03/2022.
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
import AppKit
import LegacyCommon
import Theme

protocol TickboxViewDelegate: AnyObject {
    func toggleTickbox(_ tickboxView: SettingsTickboxView, to value: ButtonState)
    func upsellTapped(_ tickboxView: SettingsTickboxView)
}

class SettingsTickboxView: NSView, SwitchButtonDelegate {

    struct ViewModel {
        let labelText: String
        let state: PaidFeatureDisplayState
        let toolTip: String?

        init(labelText: String, state: PaidFeatureDisplayState, toolTip: String? = nil) {
            self.labelText = labelText
            self.state = state
            self.toolTip = toolTip
        }

        init(labelText: String, buttonState: Bool, buttonEnabled: Bool = true, toolTip: String? = nil) {
            let state: PaidFeatureDisplayState = .available(enabled: buttonState, interactive: buttonEnabled)
            self.init(labelText: labelText, state: state, toolTip: toolTip)
        }

        enum State {
            case toggle(isInteractive: Bool, isOn: ButtonState)
            case upsell
        }
    }

    private weak var delegate: TickboxViewDelegate?

    @IBOutlet private weak var label: PVPNTextField!
    @IBOutlet private weak var switchButton: SwitchButton!
    @IBOutlet private weak var upsellImageView: HoverableButtonImageView?
    @IBOutlet private weak var separator: NSBox!
    @IBOutlet private weak var infoIcon: NSImageView!

    private var model: ViewModel?

    static let infoIcon = AppTheme.Icon.infoCircleFilled.colored(.hint)

    var isOn: Bool {
        switchButton.currentButtonState == .on
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .checkBox
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityValue() -> Any? {
        switchButton.currentButtonState == .on
    }

    override func accessibilityHelp() -> String? {
        model?.toolTip
    }

    override func accessibilityPerformPress() -> Bool {
        if let button = switchButton.buttonView {
            switchButton.buttonClicked(button)
        }
        return true
    }

    func setupItem(model: ViewModel, delegate: TickboxViewDelegate?) {
        setAccessibilityLabel(model.labelText)
        self.delegate = delegate
        self.model = model
        switchButton.delegate = self

        label.attributedStringValue = model.labelText.styled(font: .themeFont(.heading4), alignment: .left)

        infoIcon.image = model.toolTip != nil ? SettingsTickboxView.infoIcon : nil
        infoIcon.toolTip = model.toolTip
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
            switchButton.isHidden = true

        case .available(let isOn, let isInteractive):
            upsellImageView?.isHidden = true
            switchButton.isHidden = false
            switchButton.enabled = isInteractive
            switchButton.setState(isOn ? .on : .off)
        }
    }

    private func upsellImageViewTapped() {
        delegate?.upsellTapped(self)
    }

    func switchButtonClicked(_ button: NSButton) {
        delegate?.toggleTickbox(self, to: isOn ? .on : .off)
    }
}
