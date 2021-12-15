//
//  ColorPickerItem.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit

final class ColorPickerItem: UICollectionViewCell {

    @IBOutlet private weak var colorCircleView: UIView!
    
    var color: UIColor = .backgroundColor() {
        didSet {
            colorCircleView.backgroundColor = color
            backgroundColor = .clear
        }
    }

    override var isSelected: Bool {
        didSet {
            if self.isSelected {
                backgroundColor = .normalTextColor()
            } else {
                backgroundColor = .clear
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = layer.frame.size.height / 2
        colorCircleView.layer.cornerRadius = colorCircleView.layer.frame.size.height / 2
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
        translatesAutoresizingMaskIntoConstraints = true

        colorCircleView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        colorCircleView.translatesAutoresizingMaskIntoConstraints = true
        
        backgroundColor = isSelected ? .normalTextColor() : .clear
    }
}
