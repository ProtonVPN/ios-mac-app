//
//  Created on 2022-03-13.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation

#if canImport(AppKit)
import AppKit

public extension NSTextField {
    func style(placeholder: String? = nil, font: NSFont = .themeFont(), alignment: NSTextAlignment = .left) {
        self.textColor = self.color(.text)
        self.backgroundColor = self.color(.background)

        self.font = font
        self.alignment = alignment

        if let placeholder = placeholder {
            self.placeholderAttributedString = placeholder.styled(.hint, font: font, alignment: alignment)
        }
    }
}

extension NSTextField: CustomStyleContext {
    public func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            return .weak
        case .border:
            return .weak
        case .text:
            return .normal
        default:
            break
        }
        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}

#endif
