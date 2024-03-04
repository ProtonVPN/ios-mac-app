//
//  ProfileType.swift
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

public enum ProfileType: Equatable, Codable {
    
    case system
    case user
    
    public var description: String {
        switch self {
        case .system:
            return "System"
        case .user:
            return "User"
        }
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let profileType = "profileType"
    }
    
    public init(coder aDecoder: NSCoder) {
        let data = aDecoder.decodeObject(forKey: CoderKey.profileType) as! Data
        switch data[0] {
        case 0:
            self = .system
        default:
            self = .user
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
