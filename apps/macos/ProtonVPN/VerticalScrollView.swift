//
//  VerticalScrollView.swift
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

class VerticalScrollView: NSScrollView {

    override func awakeFromNib() {
        super.awakeFromNib()
        
        hasHorizontalScroller = false
    
        //let scroll = CGRect(origin: bounds.origin, size: CGSize(width: frame.size.width, height: bounds.height))
        //documentView?.frame = scroll
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if event.deltaY != 0 {
            nextResponder?.scrollWheel(with: event)
        }
    }
}
