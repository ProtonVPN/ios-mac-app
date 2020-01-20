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
    
    func applyModalAppearance(withTitle modalTitle: String) {
        styleMask.remove(NSWindow.StyleMask.resizable)
        title = modalTitle
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        backgroundColor = .protonGreyShade()
    }
    
    func applyWarningAppearance(withTitle warningTitle: String) {
        styleMask.remove(NSWindow.StyleMask.resizable)
        styleMask.remove(NSWindow.StyleMask.closable)
        title = warningTitle
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        backgroundColor = .protonGreyShade()
    }
    
    // For windows without any boarders such as the welcome window
    func applyInfoAppearance() {
        styleMask = [.titled, .fullSizeContentView]
        isOpaque = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        backgroundColor = .protonGreyShade()
    }
    
    func applyLoginAppearance() {
        //styleMask.remove(.resizable)
        titlebarAppearsTransparent = true
        title = "ProtonVPN"
        appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        backgroundColor = .protonGreyShade()
        
        //let size = NSSize(width: AppConstants.Windows.loginWidth, height: AppConstants.Windows.loginHeight)
        //minSize = size
        //maxSize = size
        //setFrame(NSRect(origin: frame.origin, size: size), display: true, animate: true)
    }

    func applySidebarAppearance() {
        //styleMask = [ .resizable, .miniaturizable, .titled, .closable ]
        titlebarAppearsTransparent = true
        title = "ProtonVPN"
        appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        backgroundColor = .protonGreyShade()
        
        minSize = NSSize(width: AppConstants.Windows.sidebarWidth, height: AppConstants.Windows.minimumSidebarHeight)
    }
}
