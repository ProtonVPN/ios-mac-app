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
import LegacyCommon
import Theme
import Ergonomics

class QuickSettingButton: NSButton {
    
    private var hovered = false
    private var trackingArea: NSTrackingArea?
    
    var detailOpened: Bool = false {
        didSet {
            if detailOpened {
                currentStyle = .enabled
            } else {
                currentStyle = .disabled
            }
        }
    }
    
    var callback: ((QuickSettingButton) -> Void)?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }
    
    override func updateLayer() {
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        layer?.masksToBounds = false
        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
    
    override func mouseUp(with event: NSEvent) {
        callback?(self)
    }
    
    func switchState(_ image: NSImage, enabled: Bool) {
        self.image = image.colored(enabled ? [.interactive, .strong] : .normal)
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

    private var currentStyle: Style = .disabled {
        didSet {
            needsDisplay = true
            updateLayer()
        }
    }
    
    private enum Style {
        case enabled
        case disabled
    }
        
    // MARK: - Mouse
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        hovered = false
        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
        }
    }
}

extension QuickSettingButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        guard context == .background else {
            log.assertionFailure("Context not handled: \(context)")
            return .normal
        }

        let hover: AppTheme.Style = hovered ? .hovered : []

        switch self.currentStyle {
        case .disabled:
            if hovered {
                return [.transparent, .active, .hovered]
            } else {
                return .normal
            }
        case .enabled:
            return [.transparent, .active] + hover
        }
    }
}
