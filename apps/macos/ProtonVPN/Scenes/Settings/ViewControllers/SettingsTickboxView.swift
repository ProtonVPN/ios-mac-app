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

import AppKit
import Foundation

import Perception

import ProtonCoreUIFoundations

import Combine
import LegacyCommon
import Strings
import Theme

protocol TickboxViewDelegate: AnyObject {
    func toggleTickbox(_ tickboxView: SettingsTickboxView, to value: ButtonState)
    func upsellTapped(_ tickboxView: SettingsTickboxView)
}

class SettingsTickboxView: NSView, SwitchButtonDelegate {
    typealias ActionHandler = () -> Void

    struct ViewModel {
        let labelText: String
        let state: PaidFeatureDisplayState
        let toolTip: String?
        let liveSource: AnyPublisher<Bool, Never>?

        init(labelText: String, state: PaidFeatureDisplayState, toolTip: String? = nil, liveSource: AnyPublisher<Bool, Never>? = nil) {
            self.labelText = labelText
            self.state = state
            self.toolTip = toolTip
            self.liveSource = liveSource
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

    @IBOutlet private var label: PVPNTextField!
    @IBOutlet private var switchButton: SwitchButton?
    @IBOutlet private var upsellImageView: HoverableButtonImageView?
    @IBOutlet private var separator: NSBox!
    @IBOutlet private var infoIcon: NSImageView?
    @IBOutlet private var onOffLabel: NSTextField?

    private var model: ViewModel?

    private var observationToken: Any?

    static let infoIcon = AppTheme.Icon.infoCircleFilled.colored(.hint)

    var isOn: Bool {
        switchButton?.currentButtonState == .on
    }

    var didTapHandler: ActionHandler?

    override func accessibilityRole() -> NSAccessibility.Role? {
        .checkBox
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityValue() -> Any? {
        switchButton?.currentButtonState == .on
    }

    override func accessibilityHelp() -> String? {
        model?.toolTip
    }

    override func accessibilityPerformPress() -> Bool {
        if let button = switchButton?.buttonView {
            switchButton?.buttonClicked(button)
        }
        return true
    }

    private func updateOnOffLabel(isOn: Bool) {
        guard let onOffLabel else { return }

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = IconProvider.chevronRight
            .colored(.color(.text))
            .resizeWhilePreservingRatio(newHeight: .themeSpacing16)
        imageAttachment.bounds = .init(
            origin: .init(x: 0, y: -2),
            size: .init(
                width: .themeSpacing16,
                height: .themeSpacing16
            )
        )
        let imageAttachmentString = NSAttributedString(attachment: imageAttachment)

        let text: String = if isOn {
            Localizable.switchSideButtonOn.capitalized + "  "
        } else {
            Localizable.switchSideButtonOff.capitalized + "  "
        }
        let isOnLabel = NSMutableAttributedString()
        let isOn = text.styled(font: .themeFont(.heading4), alignment: .right)
        isOnLabel.append(isOn)
        isOnLabel.append(imageAttachmentString)
        onOffLabel.attributedStringValue = isOnLabel
    }

    func setupItem(model: ViewModel, delegate: TickboxViewDelegate?) {
        setAccessibilityLabel(model.labelText)
        self.delegate = delegate
        self.model = model
        switchButton?.delegate = self

        label.attributedStringValue = model.labelText.styled(font: .themeFont(.heading4), alignment: .left)

        infoIcon?.image = model.toolTip != nil ? SettingsTickboxView.infoIcon : nil
        infoIcon?.toolTip = model.toolTip
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
            switchButton?.isHidden = true
            onOffLabel?.isHidden = true

        case let .available(isOn, isInteractive):
            upsellImageView?.isHidden = true
            switchButton?.isHidden = false
            switchButton?.enabled = isInteractive
            switchButton?.setState(isOn ? .on : .off)
            updateOnOffLabel(isOn: isOn)
        }

        if let liveSource = model.liveSource {
            observationToken = liveSource
                // Uncomment after VPNAPPL-3164 and after migration of `PlutoniumFeatureToggle` to `FeatureSharedKey`
                // .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] isOn in
                    guard let self else { return }
                    switchButton?.setState(isOn ? .on : .off)
                    if onOffLabel != nil {
                        updateOnOffLabel(isOn: isOn)
                    }
                }
        }
    }

    private func upsellImageViewTapped() {
        delegate?.upsellTapped(self)
    }

    func switchButtonClicked(_: NSButton) {
        delegate?.toggleTickbox(self, to: isOn ? .on : .off)
    }

    override func mouseDown(with _: NSEvent) {
        didTapHandler?()
    }
}
