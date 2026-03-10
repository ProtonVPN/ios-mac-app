//
//  ServerOffering.swift
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

// This is needed to maintain compatibility with how profiles are stored on disk
// whilst improving them with dynamic server models
public struct ServerWrapper: Codable, Equatable {
    public var _server: ServerModel

    public init(server: ServerModel) {
        self._server = server
    }

    public static func == (lhs: ServerWrapper, rhs: ServerWrapper) -> Bool {
        lhs._server.id == rhs._server.id
    }
}

public enum ServerOffering: Equatable, Codable, Sendable {
    /** Country code or undefined */
    case fastest(String?)

    /** Country code or undefined */
    case random(String?)

    /** Specific server */
    case custom(ServerWrapper)
}
