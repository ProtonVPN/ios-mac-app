//
//  Created on 2021-11-10.
//
//  Copyright (c) 2021 Proton AG
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

import Cocoa

class SubuserAlertWindowController: WindowController {
    
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
        
        window.styleMask.remove(NSWindow.StyleMask.miniaturizable)
        window.styleMask.remove(NSWindow.StyleMask.resizable)
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        window.backgroundColor = .protonGreyShade()
    }
}
