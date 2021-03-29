//
//  LoginButton.swift
//  ProtonVPN - Created on 27.06.19.
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

class LoginButtonCell: NSButtonCell {
    
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        return super.drawTitle(isEnabled ? title : attributedTitle, withFrame: frame, in: controlView)
    }
}

class LoginButton: HoverDetectionButton {
    
    override var isEnabled: Bool {
        didSet {
            needsDisplay = true
        }
    }
    
    override func awakeFromNib() {
        cell = LoginButtonCell()
        super.awakeFromNib()
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        removeCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        layer?.borderWidth = 2
        layer?.borderColor = isEnabled ? NSColor.protonGreen().cgColor : NSColor.protonLightGrey().cgColor
        layer?.backgroundColor = isEnabled ? NSColor.protonGreen().cgColor : NSColor.clear.cgColor
        attributedTitle = LocalizedString.login.attributed(withColor: isEnabled ? .protonWhite() : .protonGreyButtonBackground(), fontSize: 16)
    }
}
