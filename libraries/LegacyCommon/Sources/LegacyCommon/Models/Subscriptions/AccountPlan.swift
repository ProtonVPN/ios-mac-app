//
//  AccountPlan.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
public enum AccountPlan {
    case plus

    public var devicesCount: Int {
        switch self {
        case .plus:
            return 10
        }
    }

    public var countriesCount: Int {
        switch self {
        case .plus:
            return 85
        }
    }

    public var serversCount: Int {
        switch self {
        case .plus:
            return 4000
        }
    }
}

// This is an "exception", we don't want to keep this.
public extension String {
    var isBusiness: Bool {
        ["vpnpro2023", "vpnbiz2023"].contains(self)
    }

    var hasNetShield: Bool {
        !["free", "vpnpro2023"].contains(self)
    }
}
