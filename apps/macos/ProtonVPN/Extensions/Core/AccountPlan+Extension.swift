//
//  AccountPlan+Extension.swift
//  ProtonVPN - Created on 08/07/2019.
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

import vpncore
import AppKit
import Theme

extension AccountPlan {
    var styleForUI: AppTheme.Style {
        switch self {
        case .free:
            return .weak
        case .basic:
            return .info
        case .trial, .plus, .vpnPlus, .family, .bundlePro, .enterprise2022:
            return .success
        case .visionary, .unlimited, .visionary2022:
            return .interactive
        }
    }
}
