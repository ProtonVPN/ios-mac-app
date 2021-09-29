//
//  UIButton+Extension.swift
//  ProtonVPN - Created on 19/07/2019.
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

extension UIButton {
    
    public static func closeButton() -> UIButton {
        let closeImage = UIImage(named: "close-nav-bar")!.withRenderingMode(.alwaysTemplate)
        let closeButton = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 44, height: 44))
        closeButton.setImage(closeImage, for: .normal)
        closeButton.addConstraint(NSLayoutConstraint(item: closeButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 44))
        closeButton.addConstraint(NSLayoutConstraint(item: closeButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 44))
        closeButton.imageEdgeInsets = UIEdgeInsets.init(top: 12, left: 0, bottom: 12, right: 24)
        closeButton.tintColor = .normalTextColor()
        return closeButton
    }
    
}
