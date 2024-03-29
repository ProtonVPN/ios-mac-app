//
//  SidebarWindowController.swift
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

class SidebarWindowController: WindowController {
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewController: SidebarViewController) {
        let window = NSWindow()
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentViewController = viewController
        super.init(window: window)
        
        windowFrameAutosaveName = NSWindow.FrameAutosaveName("Main Window")
        
        setupWindow()
        setupControls()
    }
    
    private func setupWindow() {
        guard let window = window else {
            return
        }
        
        window.titlebarAppearsTransparent = true
        window.title = "Proton VPN"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .color(.background, .weak)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)

        if !AppLaunchRoutine.launchedBefore {
            let initialWidth: CGFloat = 1200
            let initialHeight: CGFloat = 600
            let initialX = window.frame.origin.x - (initialWidth - window.frame.size.width) / 2
            window.setFrameOrigin(CGPoint(x: initialX, y: window.frame.origin.y))
            window.setContentSize(CGSize(width: initialWidth, height: initialHeight))
        }
    }
    
    private func setupControls() {
        monitorsKeyEvents = true
    }
}
