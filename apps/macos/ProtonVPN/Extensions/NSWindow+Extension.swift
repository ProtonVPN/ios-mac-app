//
//  NSWindow+Extension.swift
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

extension NSWindow {
    
    func applyModalAppearance(withTitle modalTitle: String = "Proton VPN") {
        styleMask.remove(NSWindow.StyleMask.resizable)
        title = modalTitle
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }
    
    func applyWarningAppearance(withTitle warningTitle: String) {
        styleMask.remove(NSWindow.StyleMask.resizable)
        styleMask.remove(NSWindow.StyleMask.closable)
        title = warningTitle
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }
    
    // For windows without any borders such as the welcome window
    func applyInfoAppearance() {
        styleMask = [.titled, .fullSizeContentView]
        isOpaque = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }
    
    func applyLoginAppearance() {
        titlebarAppearsTransparent = true
        title = "Proton VPN"
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }

    func applySidebarAppearance() {
        titlebarAppearsTransparent = true
        title = "Proton VPN"
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
        
        minSize = NSSize(width: AppConstants.Windows.sidebarWidth, height: AppConstants.Windows.minimumSidebarHeight)
    }

    func centerWindowOnScreen() {
        guard let visibleFrame = screen?.visibleFrame,
              let size = contentView?.frame.size else {
            return
        }
        var x = visibleFrame.size.width / 2 - size.width / 2
        var y = visibleFrame.size.height / 2 - size.height / 2

        y += visibleFrame.origin.y
        x += visibleFrame.origin.x
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
