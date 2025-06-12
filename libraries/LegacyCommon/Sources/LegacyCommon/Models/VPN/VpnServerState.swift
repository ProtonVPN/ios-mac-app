//
//  VpnServerState.swift
//  vpncore - Created on 18/08/2020.
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
//

import Foundation
import VPNShared

public struct VpnServerState {
    public let id: String!
    public let domain: String!
    public let status: Int!
    public let entryIP: String!
    public let exitIP: String!

    init(dictionary: JSONDictionary) throws {
        id = try dictionary.stringOrThrow(key: "ID")
        domain = try dictionary.stringOrThrow(key: "Domain")
        status = try dictionary.intOrThrow(key: "Status")
        entryIP = try dictionary.stringOrThrow(key: "EntryIP")
        exitIP = try dictionary.stringOrThrow(key: "ExitIP")
    }
}
