//
//  ExpandCellButton.swift
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
import Theme
import Ergonomics

class ExpandCellButton: HoverDetectionButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        configureButton()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        configureButton()
    }
        
    private func configureButton() {
        wantsLayer = true
        contentTintColor = self.color(.icon)
        DarkAppearance {
            layer?.backgroundColor = self.cgColor(.background)
            layer?.borderColor = self.cgColor(.border)
        }
    }
}

extension ExpandCellButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background, .border:
            if isHovered, isEnabled {
                return [.interactive, .hovered]
            }
            return context == .border ? .normal : .weak
        case .icon:
            return .normal
        default:
            break
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
