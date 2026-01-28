//
//  Profile.swift
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

public struct Profile: Identifiable, Codable {
    public static let idLength = 20

    public let id: String
    public let accessTier: Int
    public let profileIcon: ProfileIcon
    public let profileType: ProfileType
    public let serverType: ServerType
    public let serverOffering: ServerOffering
    public let name: String
    public let connectionProtocol: ConnectionProtocol
    public let lastConnectedDate: Date?

    public var description: String {
        "ID: \(id)\n" +
            "Access tier: \(accessTier)\n" +
            "Profile icon: \(profileIcon)\n" +
            "Profile type: \(profileType)\n" +
            "Server type: \(serverType)\n" +
            "Server offering: \(serverOffering)\n" +
            "Name: \(name)\n" +
            "Protocol: \(connectionProtocol)\n" +
            "Last connected date: \(optional: lastConnectedDate)"
    }

    public init(
        id: String,
        accessTier: Int,
        profileIcon: ProfileIcon,
        profileType: ProfileType,
        serverType: ServerType,
        serverOffering: ServerOffering,
        name: String,
        connectionProtocol: ConnectionProtocol,
        lastConnectedDate: Date? = nil
    ) {
        self.id = id
        self.accessTier = accessTier
        self.profileIcon = profileIcon
        self.profileType = profileType
        self.serverType = serverType
        self.serverOffering = serverOffering
        self.name = name
        self.connectionProtocol = connectionProtocol
        self.lastConnectedDate = lastConnectedDate
    }
}
