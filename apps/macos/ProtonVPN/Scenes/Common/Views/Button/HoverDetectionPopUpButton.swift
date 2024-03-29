//
//  HoverDetectionPopUpButton.swift
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

class HoverDetectionPopUpButton: NSPopUpButton {

    override func awakeFromNib() {
        super.awakeFromNib()
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow],
                                          owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension HoverDetectionPopUpButton {
    func push(items: [PopUpButtonItemViewModel], clear: Bool = true) {
        if clear {
            removeAllItems()
        }

        for item in items {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = item.title
            menuItem.representedObject = item

            menu?.addItem(menuItem)
            if item.checked {
                select(menuItem)
            }
        }
    }

    var selectedViewModel: PopUpButtonItemViewModel? {
        menu?.item(at: indexOfSelectedItem)?.representedObject as? PopUpButtonItemViewModel
    }
}
