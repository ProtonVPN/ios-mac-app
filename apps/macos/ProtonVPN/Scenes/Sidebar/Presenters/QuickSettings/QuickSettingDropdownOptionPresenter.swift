//
//  QuickSettingDropdownOptionPresenter.swift
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

import CommonNetworking
import Theme

protocol QuickSettingDropdownOptionPresenter: AnyObject {
    var title: String { get }
    var icon: NSImage { get }
    var active: Bool { get }
    /// B2C users get upsell modals if their plan doesn't allow a feature.
    var requiresUpdate: Bool { get }

    var selectCallback: SuccessConfirmationCallback { get }
}

class QuickSettingGenericOption: QuickSettingDropdownOptionPresenter {
    let title: String
    let active: Bool
    let icon: NSImage
    let requiresUpdate: Bool
    let selectCallback: SuccessConfirmationCallback

    init(
        _ title: String,
        icon: NSImage = AppTheme.Icon.brandTor,
        active: Bool,
        requiresUpdate: Bool = false,
        selectCallback: @escaping SuccessConfirmationCallback
    ) {
        self.title = title
        self.active = active
        self.icon = icon
        self.requiresUpdate = requiresUpdate
        self.selectCallback = selectCallback
    }
}
