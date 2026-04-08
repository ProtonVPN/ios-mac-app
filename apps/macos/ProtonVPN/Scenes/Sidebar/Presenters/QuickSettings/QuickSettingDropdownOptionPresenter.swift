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

import CommonNetworking
import SwiftUI
import Theme

struct QuickSettingDropdownOption: Hashable {
    let title: String
    let icon: Image
    let active: Bool
    /// B2C users get upsell modals if their plan doesn't allow a feature.
    let requiresUpdate: Bool
    let selectCallback: SuccessConfirmationCallback

    init(
        _ title: String,
        icon: Image,
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

    static func == (lhs: QuickSettingDropdownOption, rhs: QuickSettingDropdownOption) -> Bool {
        lhs.title == rhs.title && lhs.active == rhs.active && lhs.requiresUpdate == rhs.requiresUpdate && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(active)
        hasher.combine(requiresUpdate)
    }
}
