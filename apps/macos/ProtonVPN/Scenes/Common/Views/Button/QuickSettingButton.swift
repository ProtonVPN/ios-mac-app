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
    
    private var hovered = false
    private var trackingArea: NSTrackingArea?
    
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
        
        shadow = NSShadow()
        shadow?.shadowColor = .protonDarkGrey()
        shadow?.shadowBlurRadius = 8
        
    }
    
    override func updateLayer() {
        layer?.shadowRadius = 3
        layer?.cornerRadius = 3
        layer?.masksToBounds = false
        layer?.shadowOffset = CGSize(width: 0, height: 2)
        layer?.shadowOpacity = currentStyle.shadow ? 1 : 0
        layer?.backgroundColor = hovered ? currentStyle.hoveredColor : currentStyle.color
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
    
    override func mouseUp(with event: NSEvent) {
        callback?(self)
    }
    
    func switchState( _ image: NSImage, enabled: Bool ) {
        self.image = image.colored( enabled ? .protonGreen() : .protonWhite() )
    }
    
    override func layoutSubtreeIfNeeded() {
        if let area = self.trackingArea { removeTrackingArea(area) }
        trackingArea = NSTrackingArea(rect: bounds, options: [
                                        NSTrackingArea.Options.mouseEnteredAndExited,
                                        NSTrackingArea.Options.mouseMoved,
                                        NSTrackingArea.Options.activeInKeyWindow],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    // MARK: - Styles
    
    private func setEnabledStyle() {
        currentStyle = .enabled
        needsDisplay = true
    }
    
    private func setDisabledStyle() {
        currentStyle = .disabled
        needsDisplay = true
    }
    
    private var currentStyle: Style = .disabled
    
    private enum Style {
        case enabled
        case disabled
        
        var color: CGColor {
            switch self {
            case .enabled: return NSColor.protonDarkBlueButton().cgColor
            case .disabled: return NSColor.protonQuickSettingButton().cgColor
            }
        }
        
        var hoveredColor: CGColor {
            switch self {
            case .enabled: return NSColor.protonHoverEnabled().cgColor
            case .disabled: return NSColor.protonHoverDisabled().cgColor
            }
        }
        
        var shadow: Bool {
            switch self {
            case .enabled: return false
            case .disabled: return true
            }
        }
    }
        
    // MARK: - Mouse
    
    override func mouseMoved(with event: NSEvent) {
        hovered = true
        addCursorRect(bounds, cursor: .pointingHand)
        layer?.backgroundColor = currentStyle.hoveredColor
    }
    
    override func mouseExited(with event: NSEvent) {
        hovered = false
        removeCursorRect(bounds, cursor: .pointingHand)
        layer?.backgroundColor = currentStyle.color
    }
}
