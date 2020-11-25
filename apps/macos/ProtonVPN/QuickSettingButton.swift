//
//  QuickSettingButton.swift
//  ProtonVPN - Created on 06/11/2020.
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

class QuickSettingButton: NSButton {
    
    var detailOpened: Bool = false {
        didSet {
            if detailOpened {
                setEnabledStyle()
            } else {
                setDisabledStyle()
            }
        }
    }
    
    var callback: ((QuickSettingButton) -> Void)?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.cornerRadius = 3
        shadow = NSShadow()
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
    
    override func mouseUp(with event: NSEvent) {
        callback?(self)
    }
    
    func switchState( _ image: NSImage, enabled: Bool ) {
        self.image = image.colored( enabled ? .protonGreen() : .protonWhite() )
    }
    
    // MARK: - Styles
    
    private func setEnabledStyle() {
        layer?.shadowOpacity = 0
        layer?.shadowOffset = .zero
        layer?.shadowRadius = 0
        layer?.backgroundColor = NSColor.protonDarkBlueButton().cgColor
    }
    
    private func setDisabledStyle() {
        layer?.shadowOpacity = 1
        layer?.shadowOffset = CGSize(width: 0, height: 2)
        layer?.shadowRadius = 3
        layer?.backgroundColor = NSColor.protonQuickSettingButton().cgColor
    }
}
