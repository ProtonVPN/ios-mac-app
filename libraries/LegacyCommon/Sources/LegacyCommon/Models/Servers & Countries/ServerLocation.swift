//
//  ServerLocation.swift
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
import VPNShared

public class ServerLocation: NSObject, NSCoding, Codable {
    
    public let lat: Double
    public let long: Double
    
    override public var description: String {
        return
            "Lat: \(lat)\n" +
            "Long: \(long)\n"
    }
    
    public init(lat: Double, long: Double) {
        self.lat = lat
        self.long = long
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        lat = try dic.doubleOrThrow(key: "Lat")
        long = try dic.doubleOrThrow(key: "Long")
        super.init()
    }

    /// Used for testing purposes.
    var asDict: [String: Any] {
        [
            "Lat": lat,
            "Long": long,
        ]
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let lat = "latKey"
        static let long = "longKey"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        self.init(lat: aDecoder.decodeDouble(forKey: CoderKey.lat),
                  long: aDecoder.decodeDouble(forKey: CoderKey.long))
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
