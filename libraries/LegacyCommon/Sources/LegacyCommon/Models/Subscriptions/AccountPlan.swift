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

public enum AccountPlan: String, Codable {
    
    case unknown
    case free = "free"
    case basic = "vpnbasic"
    case plus = "vpnplus"
    case visionary = "visionary"
    case visionary2022 = "visionary2022"
    case trial = "trial"
    case unlimited = "bundle2022"
    case vpnPlus = "vpn2022"
    case family = "family2022"
    case bundlePro = "bundlepro2022"
    case enterprise2022 = "enterprise2022"
    case vpnpro2023 = "vpnpro2023" // VPN Essential
    case vpnbiz2023 = "vpnbiz2023" // VPN Business
    case vpnpass2023 = "vpnpass2023"

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
            return "Proton VPN Free"
        case .basic:
            return "Proton VPN Basic"
        case .plus:
            return "Proton VPN Plus"
        case .visionary, .visionary2022:
            return "Proton Visionary"
        case .trial:
            return "Proton VPN Plus Trial"
        case .unlimited:
            return "Proton Unlimited"
        case .vpnPlus:
            return "VPN Plus"
        case .family:
            return "Proton Family"
        case .bundlePro:
            return "Business"
        case .enterprise2022:
            return "Enterprise"
        case .vpnpro2023:
            return "VPN Essentials"
        case .vpnbiz2023:
            return "VPN Business"
        case .vpnpass2023:
            return "VPN and Pass bundle"
        case .unknown:
            return "Proton VPN"
        }
    }
    
    public var devicesCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited, .visionary2022, .family, .bundlePro, .enterprise2022, .vpnpro2023, .vpnbiz2023, .vpnpass2023:
            return 10
        case .basic:
            return 2
        case .free, .trial, .unknown:
            return 1
        }
    }

    public var countriesCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited, .visionary2022, .family, .bundlePro, .enterprise2022, .vpnpro2023, .vpnbiz2023, .vpnpass2023:
            return 63
        case .basic:
            return 40
        case .free, .trial, .unknown:
            return 3
        }
    }

    public var serversCount: Int {
        switch self {
        case .plus, .visionary, .vpnPlus, .unlimited, .visionary2022, .family, .bundlePro, .enterprise2022, .vpnpro2023, .vpnbiz2023, .vpnpass2023:
            return 1600
        case .basic:
            return 400
        case .free, .trial, .unknown:
            return 24
        }
    }

    public var defaultTier: Int {
        switch self {
        case .free, .trial, .unknown:
            return CoreAppConstants.VpnTiers.free
        case .basic:
            return CoreAppConstants.VpnTiers.basic
        case .plus, .vpnPlus, .family, .bundlePro, .enterprise2022, .vpnpro2023, .vpnbiz2023, .vpnpass2023:
            return CoreAppConstants.VpnTiers.plus
        case .visionary, .unlimited, .visionary2022:
            return CoreAppConstants.VpnTiers.visionary
        }
    }

    public var hasNetShield: Bool {
        ![.free, .trial, .vpnpro2023].contains(self)
    }

    public var isBusiness: Bool {
        [.vpnpro2023, .vpnbiz2023].contains(self)
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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
