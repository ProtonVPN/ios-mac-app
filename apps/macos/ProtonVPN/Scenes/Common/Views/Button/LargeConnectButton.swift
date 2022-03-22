//
//  LargeConnectButton.swift
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
import vpncore

class LargeConnectButton: HoverDetectionButton {
    
    override var title: String {
        didSet {
            needsDisplay = true
        }
    }
    
    var isConnected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        layer?.backgroundColor = self.cgColor(.background)
        
        let title: String = isConnected ? LocalizedString.disconnect : LocalizedString.quickConnect
        layer?.borderColor = self.cgColor(.icon)
        attributedTitle = self.style(title, font: .themeFont(.heading4))
    }
}

extension LargeConnectButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            return .transparent
        case .icon, .text:
            if isConnected {
                return isHovered ? .danger : .normal
            }
            return isHovered ? [.interactive, .active] : .normal
        default:
            break
        }

        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
