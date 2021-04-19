//
//  NSStackView+Children.swift
//  ProtonVPN - Created on 2021-04-15.
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

extension NSStackView {
        
    /// Removed all arranged subviews.
    /// Keep in mind that views should be retained if you inted to reuse them.
    func clear() {
        self.arrangedSubviews.forEach {
            self.removeArrangedSubview( $0 )
            $0.removeFromSuperview()
        }
    }
    
}
