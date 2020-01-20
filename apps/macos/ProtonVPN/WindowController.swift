//
//  WindowController.swift
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

protocol WindowControllerDelegate: class {
 
    func windowCloseRequested(_ sender: WindowController)
    func windowWillClose(_ sender: WindowController)
}

class WindowController: NSWindowController {
    
    private var eventMonitor: Any?
    
    var monitorsKeyEvents: Bool? {
        didSet {
            configureEventMonitor()
        }
    }
    
    weak var delegate: WindowControllerDelegate?
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    override init(window: NSWindow?) {
        super.init(window: window)
        window?.delegate = self
    }
    
    deinit {
        removeEventMonitor()
    }
    
    // MARK: - Private functions
    private func configureEventMonitor() {
        guard let monitorsKeyEvents = monitorsKeyEvents else {
            return
        }
        
        monitorsKeyEvents ? addEventMonitor() : removeEventMonitor()
    }
    
    private func addEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let `self` = self else { return nil }
            
            if event.window != self.window {
                return event
            }
            
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 13 {
                if let delegate = self.delegate {
                    delegate.windowCloseRequested(self)
                } else {
                    self.close()
                }
                return nil
            }
            return event
        }
    }
    
    private func removeEventMonitor() {
        guard let eventMonitor = eventMonitor else {
            return
        }
        
        NSEvent.removeMonitor(eventMonitor)
    }
}

// MARK: - Handling action on 'X' window button press
extension WindowController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let delegate = delegate {
            delegate.windowCloseRequested(self)
            return false
        } else {
            return true
        }
    }
}
