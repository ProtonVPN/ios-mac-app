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
import SwiftUI

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
        centerWindow(in: screen)
    }

    func centerWindow(in screen: NSScreen? = NSScreen.main) {
        let screen = screen ?? self.screen
        guard let visibleFrame = screen?.visibleFrame,
              let size = viewSize else {
            return
        }
        var x = visibleFrame.size.width / 2 - size.width / 2
        var y = visibleFrame.size.height / 2 - size.height / 2

        y += visibleFrame.origin.y
        x += visibleFrame.origin.x
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // Sizes the window according to a known content size.
    func positionWindow(size: CGSize) {
        guard let visibleFrame = screen?.visibleFrame else {
            return
        }
        let freeHeight = max(0, visibleFrame.height - size.height)
        let freeWidth = max(0, visibleFrame.width - size.width)
        setFrameOrigin(.init(x: freeWidth / 2,
                             y: size.height + freeHeight / 2))
    }
}

private extension NSWindow {
    var viewSize: CGSize? {
        let contentViewSize = contentView?.frame.size
        if contentViewSize != .zero {
            return contentViewSize
        }
        if let hostingController = contentViewController as? ExplicitlySizedHostingController {
            return hostingController.viewSize
        }
        return contentViewController?.preferredContentSize
    }
}
