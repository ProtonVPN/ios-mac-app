//
//  ButtonImageView.swift
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

class ButtonImageView: NSImageView {

    var imageClicked: (() -> Void)?
    
    override func mouseUp(with event: NSEvent) {
        imageClicked?()
    }
    
}

class HoverableButtonImageView: ButtonImageView {

    override open func awakeFromNib() {
        super.awakeFromNib()

        let trackingArea = NSTrackingArea(rect: bounds,
                                          options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeAlways],
                                          owner: self,
                                          userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override open func mouseEntered(with event: NSEvent) {
        if isEnabled {
            self.addCursorRect(bounds, cursor: NSCursor.pointingHand)
        }
    }

    override open func mouseExited(with event: NSEvent) {
        if isEnabled {
            self.addCursorRect(bounds, cursor: NSCursor.arrow)
        }
    }
}
