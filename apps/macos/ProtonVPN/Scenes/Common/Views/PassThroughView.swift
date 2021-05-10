//
//  PassThroughView.swift
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

// Allows pass through of hit test when hit test fails on subviews
class PassThroughView: NSView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = super.hitTest(point) {
            if view == self {
                return nil
            } else {
                return view
            }
        }
        return nil
    }
}

class PassThroughImageView: NSImageView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = super.hitTest(point) {
            if view == self {
                return nil
            } else {
                return view
            }
        }
        return nil
    }
}

class PassThroughTextField: NSTextField {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = super.hitTest(point) {
            if view == self {
                return nil
            } else {
                return view
            }
        }
        return nil
    }
}
