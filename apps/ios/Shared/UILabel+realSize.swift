//
//  UILabel+realSize.swift
//  ProtonVPN - Created on 01/04/2020.
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

extension UILabel {

    /// Calculate the real content size of a UILabel which value could be depending of a second view p.e: stackviews.
    var realSize: CGSize {
        let sizeLabel = UILabel()
        sizeLabel.numberOfLines = numberOfLines
        sizeLabel.font = font
        sizeLabel.text = text
        sizeLabel.attributedText = attributedText
        sizeLabel.sizeToFit()
        return sizeLabel.bounds.size
    }
}
