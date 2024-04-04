//
//  ContinuousServerProperties.swift
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

import Domain

public typealias ContinuousServerPropertiesDictionary = [String: ContinuousServerProperties]

extension ContinuousServerProperties {

    public init(dic: JSONDictionary) throws {
        self.init(
            serverId: try dic.stringOrThrow(key: "ID"), // "ID": "ABC",
            load: try dic.intOrThrow(key: "Load"), // "Load": "15"
            score: try dic.doubleOrThrow(key: "Score"), // "Score": "1.4454542"
            status: try dic.intOrThrow(key: "Status") // "Status": 1
        )
    }

    var asDict: [String: Any] {
        [
            "ID": serverId,
            "Load": load,
            "Score": score,
            "Status": status,
        ]
    }
}
