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

class ColorPickerItem: UICollectionViewCell {
    
    @IBOutlet weak var spaceBackgroundView: UIView!
    @IBOutlet weak var colorCircleView: UIView!
    
    var color: UIColor = .protonGrey() {
        didSet {
            colorCircleView.backgroundColor = color
            backgroundColor = .protonGrey()
        }
    }

    override var isSelected: Bool {
        didSet {
            if self.isSelected {
                backgroundColor = .protonWhite()
            } else {
                backgroundColor = .protonGrey()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.cornerRadius = self.frame.size.height / 2

        let bgFrame = spaceBackgroundView.frame
        spaceBackgroundView.layer.cornerRadius = bgFrame.size.height / 2

        colorCircleView.frame = CGRect(x: bgFrame.origin.x + 4,
                                       y: bgFrame.origin.y + 4,
                                       width: bgFrame.size.width - 8,
                                       height: bgFrame.size.height - 8)
        colorCircleView.layer.cornerRadius = colorCircleView.frame.size.height / 2
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

//        self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//        self.translatesAutoresizingMaskIntoConstraints = true
        
        backgroundColor = .protonGrey()
        spaceBackgroundView.backgroundColor = .protonGrey()
    }
}
