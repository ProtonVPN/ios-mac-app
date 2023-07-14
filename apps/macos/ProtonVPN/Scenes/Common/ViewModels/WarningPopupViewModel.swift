//
//  WarningPopupViewModel.swift
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
import vpncore
import Theme

class WarningPopupViewModel {
    
    let image: NSImage?
    let title: String
    let description: String
    let linkDescription: String?
    let url: String?

    let onConfirm: () -> Void
    let confirmTitle: String
    let onCancel: (() -> Void)?
    let cancelTitle: String
    
    init(image: NSImage? = AppTheme.Icon.vpnMainTransparent,
         title: String,
         description: String,
         linkDescription: String?,
         url: String?,
         onConfirm: @escaping () -> Void,
         confirmTitle: String = LocalizedString.ok,
         onCancel: (() -> Void)?,
         cancelTitle: String = LocalizedString.cancel) {
        self.image = image
        self.title = title
        self.description = description
        self.onConfirm = onConfirm
        self.confirmTitle = confirmTitle
        self.onCancel = onCancel
        self.cancelTitle = cancelTitle
        self.linkDescription = linkDescription
        self.url = url
    }
    
    convenience init(image: NSImage? = AppTheme.Icon.vpnMainTransparent, title: String, description: String, onConfirm: @escaping () -> Void) {
        self.init(image: image, title: title, description: description, linkDescription: nil, url: nil, onConfirm: onConfirm, onCancel: nil)
    }

    convenience init(image: NSImage? = AppTheme.Icon.vpnMainTransparent, title: String, description: String, linkDescription: String?, url: String?, onConfirm: @escaping () -> Void) {
        self.init(image: image, title: title, description: description, linkDescription: linkDescription, url: url, onConfirm: onConfirm, onCancel: nil)
    }
}
