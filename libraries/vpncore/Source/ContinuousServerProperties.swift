//
//  ContinuousServerProperties.swift
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

public typealias ContinuousServerPropertiesDictionary = [String: ContinuousServerProperties]

public class ContinuousServerProperties: NSObject {
    
    public let serverId: String
    public let load: Int
    public let score: Double
    
    override public var description: String {
        return
            "ServerID: \(serverId)\n" +
            "Load: \(load)\n" +
            "Score: \(score)"
    }
    
    public init(serverId: String, load: Int, score: Double) {
        self.serverId = serverId
        self.load = load
        self.score = score
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        serverId = try dic.stringOrThrow(key: "ID") //"ID": "ABC"
        load = try dic.intOrThrow(key: "Load") //"Load": "15"
        score = try dic.doubleOrThrow(key: "Score") //"Score": "1.4454542"
        super.init()
    }
}
