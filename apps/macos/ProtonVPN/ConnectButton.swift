//
//  ConnectButton.swift
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

class ConnectButton: ResizingTextButton {
    
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
    
    var upgradeRequired: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var nameForAccessibility: String? {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
        setAccessibilityRole(.button)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }
    
    private func configureButton() {
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        layer?.borderWidth = 2
        
        if isConnected {
            layer?.backgroundColor = NSColor.protonGrey().cgColor
            if isHovered {
                layer?.borderColor = NSColor.protonRed().cgColor
                layer?.backgroundColor = NSColor.protonRed().cgColor
                attributedTitle = LocalizedString.disconnect.uppercased().attributed(withColor: .protonWhite(), fontSize: 12)
            } else {
                layer?.borderColor = NSColor.protonLightGrey().cgColor
                attributedTitle = LocalizedString.connected.uppercased().attributed(withColor: .protonWhite(), fontSize: 12)
            }
            setAccessibilityLabel(String(format: "%@ %@", LocalizedString.disconnect, nameForAccessibility ?? ""))
        } else {
            let titleText = upgradeRequired ? LocalizedString.upgrade : LocalizedString.connect
            attributedTitle = titleText.uppercased().attributed(withColor: .protonWhite(), fontSize: 12)
            if isHovered {
                layer?.borderColor = NSColor.protonGreen().cgColor
                layer?.backgroundColor = NSColor.protonGreen().cgColor
            } else {
                layer?.borderColor = NSColor.protonLightGrey().cgColor
                layer?.backgroundColor = NSColor.protonGrey().cgColor
            }
            setAccessibilityLabel(String(format: "%@ %@", titleText, nameForAccessibility ?? ""))
        }
        
    }
}
