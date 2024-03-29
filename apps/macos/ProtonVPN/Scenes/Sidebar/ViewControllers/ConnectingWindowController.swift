//
//  ConnectingWindow.swift
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

class ConnectingWindowController: WindowController {
        
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewController: ConnectingViewController) {
        let window = ConnectingOverlayWindow(contentViewController: viewController)
        super.init(window: window)
        
        setupWindow()
        monitorsKeyEvents = true
    }
    
    private func setupWindow() {
        guard let window = window else {
            return
        }
        
        window.styleMask = .borderless
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.appearance = NSAppearance(named: .darkAqua)
        
        window.ignoresMouseEvents = false
    }
}

class ConnectingOverlayWindow: NSWindow {
    
    // This makes `addCursorRect` in `ConnectingOverlayButton` work.
    override var canBecomeKey: Bool {
        return true
    }
    
}
