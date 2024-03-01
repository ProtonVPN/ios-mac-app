//
//  LoginButton.swift
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
import LegacyCommon
import Theme
import Ergonomics
import Strings

class LoginButton: HoverDetectionButton {
    var displayTitle: String?
    
    override var isEnabled: Bool {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        layer?.borderWidth = 2
        DarkAppearance {
            layer?.borderColor = self.cgColor(.border)
            layer?.backgroundColor = self.cgColor(.background)
        }
        attributedTitle = self.style((displayTitle ?? Localizable.login), font: .themeFont(.heading4))
    }
}

extension LoginButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            return isEnabled ? .interactive : .transparent
        case .border:
            return isEnabled ? .interactive : .weak
        case .text:
            return isEnabled ? .normal : .weak
        default:
            break
        }
        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
