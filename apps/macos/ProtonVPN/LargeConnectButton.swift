//
//  LargeConnectButton.swift
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

class LargeConnectButton: HoverDetectionButton {
    
    override var title: String {
        didSet {
            needsDisplay = true
        }
    }
    
    var isConnected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = NSColor.clear.cgColor
        
        let title: String
        let accentColor: NSColor
        
        if isConnected {
            accentColor = isHovered ? .protonRed() : .protonWhite()
            title = LocalizedString.disconnect
        } else {
            accentColor = isHovered ? .protonGreen() : .protonWhite()
            title = LocalizedString.quickConnect
        }
        
        layer?.borderColor = accentColor.cgColor
        attributedTitle = title.attributed(withColor: accentColor, fontSize: 16)
    }
}
