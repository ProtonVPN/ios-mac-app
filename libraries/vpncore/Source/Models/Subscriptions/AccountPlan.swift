//
//  AccountPlan.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public enum AccountPlan: String {
    
    case free = "free"
    case basic = "vpnbasic"
    case plus = "vpnplus"
    case visionary = "visionary"
    case trial = "trial"
    case unlimited = "bundle2022"
    case vpnPlus = "vpn2022"
    
    public var paid: Bool {
        switch self {
        case .free, .trial:
            return false
        default:
            return true
        }
    }
    
    public var description: String {
        switch self {
        case .free:
            return "ProtonVPN Free"
        case .basic:
            return "ProtonVPN Basic"
        case .plus:
            return "ProtonVPN Plus"
        case .visionary:
            return "Proton Visionary"
        case .trial:
            return "ProtonVPN Plus Trial"
        case .unlimited:
            return "Proton Unlimited"
        case .vpnPlus:
            return "VPN Plus"
        }
    }
    
    public var devicesCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited:
            return 10
        case .basic:
            return 2
        case .free, .trial:
            return 1
        }
    }

    public var countriesCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited:
            return 61
        case .basic:
            return 40
        case .free, .trial:
            return 3
        }
    }

    public var serversCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited:
            return 1600
        case .basic:
            return 400
        case .free, .trial:
            return 24
        }
    }

    public var defaultTier: Int {
        switch self {
        case .free, .trial:
            return CoreAppConstants.VpnTiers.free
        case .basic:
            return CoreAppConstants.VpnTiers.basic
        case .plus, .vpnPlus:
            return CoreAppConstants.VpnTiers.plus
        case .visionary, .unlimited:
            return CoreAppConstants.VpnTiers.visionary
        }
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let accountPlan = "accountPlan"
    }
    
    public init(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObject(forKey: CoderKey.accountPlan) as! String
        self.init(rawValue: name)!
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(rawValue, forKey: CoderKey.accountPlan)
    }
}
