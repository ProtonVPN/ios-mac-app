//
//  SysexWizardWindowController.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-09-06.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Cocoa

class SysexGuideWindowController: WindowController {
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewController: NSViewController) {
        let window = NSWindow(contentViewController: viewController)
        super.init(window: window)
        
        setupWindow()
        monitorsKeyEvents = true
    }
    
    private func setupWindow() {
        guard let window = window else {
            return
        }

        window.title = ""
        window.styleMask.remove(NSWindow.StyleMask.miniaturizable)
        window.styleMask.remove(NSWindow.StyleMask.resizable)
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .color(.background, .weak)
    }
}
