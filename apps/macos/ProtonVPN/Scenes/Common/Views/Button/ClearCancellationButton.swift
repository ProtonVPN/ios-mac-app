//
//  ClearCancellationButton.swift
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

class ClearCancellationButton: HoverDetectionButton {
    override var title: String {
        didSet {
            configureTitle()
        }
    }
    
    var fontSize: AppTheme.FontSize = .heading4 {
        didSet {
            configureTitle()
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.borderColor = self.cgColor(.border)
        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = self.cgColor(.background)
        attributedTitle = self.style(title, font: .themeFont(fontSize))
    }
    
    private func configureTitle() {
        attributedTitle = self.style(title, font: .themeFont(fontSize))
    }
}

extension ClearCancellationButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            return isHovered ? .inverted : .transparent
        case .border:
            return .inverted
        case .text:
            return isHovered ? .weak : .normal
        default:
            break
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
