//
//  PVPNTextField.swift
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

class PVPNTextField: NSTextField {
    
    override var attributedStringValue: NSAttributedString {
        didSet {
            setBackgroundColor()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTransparency()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTransparency()
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        setBackgroundColor()
    }
    
    private func setupTransparency() {
        isBordered = false
        focusRingType = .none
        drawsBackground = false
    }
    
    private func setBackgroundColor() {
        var nextSuperview: NSView? = superview
        while nextSuperview != nil {
            if let bgColor = nextSuperview?.layer?.backgroundColor {
                drawsBackground = true
                backgroundColor = NSColor(cgColor: bgColor)
                break
            } else {
                nextSuperview = nextSuperview?.superview
            }
        }
    }
}
