//
//  NSFont+Extension.swift
//  ProtonVPN - Created on 26/11/2020.
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

extension NSFont {
    
    static func italicSystem( ofSize size: CGFloat ) -> NSFont {
        return systemFont(ofSize: size).with(.italic)
    }
    
    static func boldItalicSystem( ofSize size: CGFloat ) -> NSFont {
        return systemFont(ofSize: size).with(.italic, .bold)
    }
    
    func with(_ traits: NSFontDescriptor.SymbolicTraits...) -> NSFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(
            NSFontDescriptor.SymbolicTraits(traits).union(self.fontDescriptor.symbolicTraits)
        )
        return NSFont(descriptor: descriptor, size: 0) ?? self
    }

    func without(_ traits: NSFontDescriptor.SymbolicTraits...) -> NSFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(
            self.fontDescriptor.symbolicTraits.subtracting(NSFontDescriptor.SymbolicTraits(traits))
        )
        return NSFont(descriptor: descriptor, size: 0) ?? self
    }
}
