//
//  UIView+constraints.swift
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

extension UIView {

    func addFillingSubview(_ subView: UIView) {
        self.addSubview(subView)
        
        subView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        subView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        subView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        subView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    }
    
    func add(subView: UIView, withTopMargin topMargin: CGFloat? = nil, rightMargin: CGFloat? = nil, bottomMargin: CGFloat? = nil, leftMargin: CGFloat? = nil) {
        self.addSubview(subView)
        
        if let topMargin = topMargin {
            subView.topAnchor.constraint(equalTo: self.topAnchor, constant: topMargin).isActive = true
        }
        if let bottomMargin = bottomMargin {
            subView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: bottomMargin).isActive = true
        }
        if let leftMargin = leftMargin {
            subView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: leftMargin).isActive = true
        }
        if let rightMargin = rightMargin {
            subView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: rightMargin).isActive = true
        }
    }
    
}
