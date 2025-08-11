//
//  QuickSettingsDropdownOption.swift
//  ProtonVPN - Created on 04/11/2020.
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

import Cocoa
import CommonNetworking
import Ergonomics
import LegacyCommon
import Strings
import Theme

class QuickSettingsDropdownOption: NSView {
    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var containerView: NSView!
    @IBOutlet var optionIconIV: NSImageView!
    @IBOutlet var plusIconView: NSImageView!

    var action: SuccessCallback?

    private var state: State = .blocked
    private var isHovered: Bool = false

    @IBAction
    func didTapActionBtn(_: Any) {
        action?()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyTrackingArea()

        wantsLayer = true
        layer?.masksToBounds = false

        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = false
        containerView.layer?.borderWidth = 1
        containerView.layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        setBackground()

        plusIconView.image = Theme.Asset.vpnSubscriptionBadge.image

        optionIconIV.cell?.setAccessibilityElement(false)
    }

    // MARK: - Styles

    private enum State {
        case selected
        case unselected
        case blocked
    }

    func selectedStyle() {
        state = .selected
        containerView.shadow = nil
        applyState()
    }

    func disabledStyle() {
        state = .unselected
        applyState()
    }

    func blockedStyle() {
        state = .blocked
        plusIconView.isHidden = false
        applyState()
    }

    // MARK: - Private

    private func setBackground() {
        DarkAppearance {
            containerView.layer?.backgroundColor = self.cgColor(.background)
            containerView.layer?.borderColor = self.cgColor(.border)
        }
    }

    private func applyState() {
        setBackground()
        if let image = optionIconIV.image {
            optionIconIV.image = colorImage(image)
        }
        titleLabel.attributedStringValue = style(titleLabel.stringValue, alignment: .left)
    }

    private func applyTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved,
                NSTrackingArea.Options.activeInKeyWindow,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - Mouse

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
        setBackground()
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        setBackground()
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityChildren() -> [Any]? {
        []
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func accessibilityLabel() -> String? {
        titleLabel.stringValue
    }

    override func accessibilityPerformPress() -> Bool {
        action?()
        return true
    }
}

extension QuickSettingsDropdownOption: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style { // swiftlint:disable:this cyclomatic_complexity
        let hover: AppTheme.Style = isHovered ? .hovered : []

        switch context {
        case .background:
            switch state {
            case .blocked:
                return .transparent
            default:
                return .transparent + (isHovered ? .hovered : [])
            }
        case .border:
            switch state {
            case .blocked:
                return .transparent
            case .unselected:
                return .normal
            case .selected:
                return [.interactive, .hint] + hover
            }
        case .text, .icon:
            switch state {
            case .blocked:
                return [.interactive, .weak]
            case .unselected:
                return .normal
            case .selected:
                return [.interactive, .hint] + hover
            }
        default:
            break
        }
        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
