//
//  QuickSettingsDropdownOptionPresenter.swift
//  ProtonVPN - Created on 10/11/2020.
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

protocol QuickSettingsDropdownOptionPresenter {
    var selectedColor: NSColor! { get }
    var title: String! { get }
    var icon: NSImage! { get }
    var active: Bool! { get }
    var requiresUpdate: Bool! { get }
    
    var selectCallback: SuccessCallback? { get }
}

class QuickSettingGenericOption: QuickSettingsDropdownOptionPresenter {
    
    let selectedColor: NSColor!
    let title: String!
    let active: Bool!
    var icon: NSImage! = #imageLiteral(resourceName: "protonvpn-server-tor-list")
    var requiresUpdate: Bool!
    var selectCallback: (() -> Void)?
    
    init( _ title: String, icon: NSImage, selectedColor: NSColor = .protonGreen(), active: Bool, requiresUpdate: Bool = false, selectCallback: SuccessCallback? = nil ) {
        self.title = title
        self.active = active
        self.selectedColor = selectedColor
        self.icon = icon
        self.requiresUpdate = requiresUpdate
        self.selectCallback = selectCallback
    }
}
