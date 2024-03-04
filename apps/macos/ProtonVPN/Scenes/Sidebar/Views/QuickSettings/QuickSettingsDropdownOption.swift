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
import LegacyCommon
import Theme
import Ergonomics
import Strings

class QuickSettingsDropdownOption: NSView {
        
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var containerView: NSView!
    @IBOutlet weak var optionIconIV: NSImageView!
    @IBOutlet weak var plusBox: NSBox!
    @IBOutlet weak var plusText: NSTextField!
    @IBOutlet var plusAndTitleConstraint: NSLayoutConstraint!
    
    var action: SuccessCallback?
    
    private var state: State = .blocked(business: false)
    private var isHovered: Bool = false

    @IBAction func didTapActionBtn(_ sender: Any) {
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

        plusBox.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        plusText.stringValue = Localizable.plus
        plusAndTitleConstraint.isActive = false

        optionIconIV.cell?.setAccessibilityElement(false)
    }
    
    // MARK: - Styles
    
    private enum State {
        case selected
        case unselected
        case blocked(business: Bool)
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
    
    func blockedStyle(business: Bool) {
        state = .blocked(business: business)
        plusBox.isHidden = business
        plusAndTitleConstraint.isActive = true
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
            optionIconIV.image = self.colorImage(image)
        }
        titleLabel.attributedStringValue = self.style(titleLabel.stringValue, alignment: .left)
    }
    
    private func applyTrackingArea() {
        let trackingArea = NSTrackingArea(rect: bounds, options: [
                                        NSTrackingArea.Options.mouseEnteredAndExited,
                                        NSTrackingArea.Options.mouseMoved,
                                        NSTrackingArea.Options.activeInKeyWindow],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Mouse

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        self.isHovered = true
        setBackground()
    }
    
    override func mouseExited(with event: NSEvent) {
        self.isHovered = false
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
            switch self.state {
            case .blocked:
                return .transparent
            default:
                return .transparent + (isHovered ? .hovered : [])
            }
        case .border:
            switch self.state {
            case .blocked:
                return .transparent
            case .unselected:
                return .normal
            case .selected:
                return [.interactive, .hint] + hover
            }
        case .text, .icon:
            switch self.state {
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
