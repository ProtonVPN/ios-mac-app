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
import vpncore

class QuickSettingsDropdownOption: NSView {
    
    var selectedColor: NSColor = .protonGreen()
    
    @IBOutlet weak var getPlusWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var containerBox: NSBox!
    @IBOutlet weak var optionIconIV: NSImageView!
    @IBOutlet weak var plusBox: NSBox!
    
    var action: SuccessCallback?
    
    @IBAction func didTapActionBtn(_ sender: Any) {
        action?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        applyTrackingArea()
    }
    
    // MARK: - Styles
    
    func selectedStyle() {
        getPlusWidthConstraint.constant = 12
        wantsLayer = true
        containerBox.shadow = nil
        containerBox.wantsLayer = true
        containerBox.layer?.backgroundColor = NSColor.protonDarkBlueButton().cgColor
        containerBox.layer?.cornerRadius = 3
        optionIconIV.image = optionIconIV.image?.colored(selectedColor)
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: selectedColor,
            fontSize: 14,
            alignment: .left)
    }
    
    func disabledStyle() {
        applyShadow()
        getPlusWidthConstraint.constant = 12
        optionIconIV.image = optionIconIV.image?.colored(.protonWhite())
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: .protonWhite(),
            fontSize: 14,
            alignment: .left)
    }
    
    func blockedStyle() {
        getPlusWidthConstraint.constant = 48
        applyShadow()
        
        plusBox.isHidden = false
        optionIconIV.image = optionIconIV.image?.colored(.protonGreyUnselectedWhite())
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: .protonGreyUnselectedWhite(),
            fontSize: 14,
            alignment: .left)
    }
    
    // MARK: - Private
    
    private func applyShadow() {
        wantsLayer = true
        layer?.masksToBounds = false
        containerBox.wantsLayer = true
        containerBox.cornerRadius = 3
        containerBox.layer?.masksToBounds = false
        containerBox.layer?.backgroundColor = NSColor.protonGrey().cgColor
        containerBox.layer?.cornerRadius = 3
        containerBox.shadow = NSShadow()
        containerBox.layer?.shadowOpacity = 1
        containerBox.layer?.shadowOffset = CGSize(width: 0, height: -2)
        containerBox.layer?.shadowRadius = 3
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
    
    override func mouseMoved(with event: NSEvent) {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func mouseExited(with event: NSEvent) {
        removeCursorRect(bounds, cursor: .pointingHand)
    }
}
