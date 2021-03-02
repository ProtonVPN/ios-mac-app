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
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var containerView: NSView!
    @IBOutlet weak var optionIconIV: NSImageView!
    @IBOutlet weak var plusBox: NSBox!
    @IBOutlet weak var plusText: NSTextField!
    @IBOutlet var plusAndTitleConstraint: NSLayoutConstraint!
    
    var action: SuccessCallback?
    
    @IBAction func didTapActionBtn(_ sender: Any) {
        action?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        applyTrackingArea()
        
        wantsLayer = true
        layer?.masksToBounds = false
        
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 3
        containerView.layer?.masksToBounds = false
        containerView.layer?.backgroundColor = NSColor.protonGrey().cgColor
    
        plusText.stringValue = LocalizedString.upgrade.uppercased()
        plusAndTitleConstraint.isActive = false
    }
    
    // MARK: - Styles
    
    func selectedStyle() {
        containerView.shadow = nil
        containerView.layer?.backgroundColor = NSColor.protonDarkBlueButton().cgColor
        optionIconIV.image = optionIconIV.image?.colored(selectedColor)
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: selectedColor,
            fontSize: 14,
            alignment: .left)
    }
    
    func disabledStyle() {
        containerView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        applyShadow()
        optionIconIV.image = optionIconIV.image?.colored(.protonWhite())
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: .protonWhite(),
            fontSize: 14,
            alignment: .left)
    }
    
    func blockedStyle() {
        containerView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        applyShadow()
        
        plusBox.isHidden = false
        plusAndTitleConstraint.isActive = true
        optionIconIV.image = optionIconIV.image?.colored(.protonGreyUnselectedWhite())
        titleLabel.attributedStringValue = titleLabel.stringValue.attributed(
            withColor: .protonGreyUnselectedWhite(),
            fontSize: 14,
            alignment: .left)
    }
    
    // MARK: - Private
    
    private func applyShadow() {
        let addShadow = NSShadow()
        addShadow.shadowColor = .protonDarkGrey()
        addShadow.shadowBlurRadius = 3
        containerView.shadow = addShadow
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
