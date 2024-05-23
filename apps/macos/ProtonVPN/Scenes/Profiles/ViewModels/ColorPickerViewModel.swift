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
import LegacyCommon

class ColorPickerViewModel {
    private let colors: [NSColor]
    
    var colorSelected: (() -> Void)?
    
    var colorCount: Int {
        return colors.count
    }
    
    var selectedColorIndex: Int {
        didSet {
            guard selectedColorIndex < colors.count else {
                selectedColorIndex = 0
                return
            }
            colorSelected?()
        }
    }

    var selectedColor: NSColor {
        color(atIndex: selectedColorIndex)
    }
    
    init() {
        colors = ProfileConstants.profileColors
        selectedColorIndex = colors.randomIndex
    }
    
    func selectRandom() {
        selectedColorIndex = colors.randomIndex
    }
    
    func select(rgbHex: Int) {
        if let newIndex = colors.firstIndex(where: { $0.hexRepresentation == rgbHex }) {
            selectedColorIndex = newIndex
        }
    }
    
    func select(index: Int) {
        if index >= 0 && index < colorCount {
            selectedColorIndex = index
        }
    }
    
    func color(atIndex index: Int) -> NSColor {
        return colors[index]
    }
}

private extension Array {
    var randomIndex: Index {
        Index(arc4random_uniform(UInt32(count))) // swiftlint:disable:this legacy_random
    }
}
