//
//  ColorPickerViewModel.swift
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

class ColorPickerViewModel {
    
    private let colors: [NSColor]
    
    var colorSelected: (() -> Void)?
    
    var colorCount: Int {
        return colors.count
    }
    
    var selectedColorIndex: Int {
        didSet {
            colorSelected?()
        }
    }
    
    init() {
        colors = ProfileConstants.profileColors
        selectedColorIndex = Int(arc4random_uniform(UInt32(colors.count)))
    }
    
    func selectRandom() {
        selectedColorIndex = Int(arc4random_uniform(UInt32(colorCount)))
    }
    
    func select(color newColor: NSColor?) {
        guard let newColor = newColor else {
            selectRandom()
            return
        }
        
        for (index, color) in colors.enumerated() where color == newColor {
            selectedColorIndex = index
            break
        }
    }
    
    func select(color index: Int) {
        if index >= 0 && index < colorCount {
            selectedColorIndex = index
        }
    }
    
    func color(atIndex index: Int) -> NSColor {
        return colors[index]
    }
}
