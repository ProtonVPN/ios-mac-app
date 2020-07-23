//
//  MigrationVersion.swift
//  vpncore - Created on 23/07/2020.
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
//

import Foundation

public struct MigrationVersion: Equatable {
    
    fileprivate var versionString: String!
    
    public init( _ version: String ) {
        self.versionString = version
    }
}

// MARK: - Codable

extension MigrationVersion: Codable {
    
    private enum Key: CodingKey {
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        versionString = try container.decode(String.self, forKey: .version)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(versionString, forKey: .version)
    }
}

// MARK: - Compare

public func > (_ v1: MigrationVersion, v2: MigrationVersion) -> Bool {
    let segment1 = v1.versionString.split(separator: ".")
    let segment2 = v2.versionString.split(separator: ".")
    let maxValue = max(segment1.count, segment2.count)
    
    for x in 0..<maxValue {
        guard segment1.count < x, let int1 = Int(segment1[x]) else { return false }
        guard segment2.count < x, let int2 = Int(segment2[x]) else { return true }
        if  int1 != int2 { int1 > int2 }
    }
    
    return true
}
