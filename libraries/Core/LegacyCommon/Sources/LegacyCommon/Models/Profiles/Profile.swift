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

import CommonNetworking
import Domain
import Foundation
import VPNAppCore
import VPNShared

public extension Profile {
    var logDescription: String {
        description
    }

    var isDefaultProfile: Bool {
        ProfileConstants.defaultIds.contains(id)
    }

    func connectionRequest(
        withDefaultNetshield netShield: NetShieldType,
        withDefaultNATType natType: NATType,
        withDefaultSafeMode safeMode: Bool?,
        withDefaultPortForwarding portForwarding: Bool?,
        trigger: UserInitiatedVPNChange.VPNTrigger?
    ) -> ConnectionRequest {
        switch serverOffering {
        case let .fastest(countryCode):
            let connectionType: ConnectionRequestType = countryCode.flatMap { ConnectionRequestType.country($0, .fastest) } ?? ConnectionRequestType.fastest
            return ConnectionRequest(
                serverType: serverType,
                connectionType: connectionType,
                connectionProtocol: connectionProtocol,
                netShieldType: netShield,
                natType: natType,
                safeMode: safeMode,
                portForwarding: portForwarding,
                profileId: id,
                profileName: name,
                trigger: trigger
            )
        case let .random(countryCode):
            let connectionType: ConnectionRequestType = countryCode.flatMap { ConnectionRequestType.country($0, .random) } ?? ConnectionRequestType.random
            return ConnectionRequest(
                serverType: serverType,
                connectionType: connectionType,
                connectionProtocol: connectionProtocol,
                netShieldType: netShield,
                natType: natType,
                safeMode: safeMode,
                portForwarding: portForwarding,
                profileId: id,
                profileName: name,
                trigger: trigger
            )
        case let .custom(serverWrapper):
            return ConnectionRequest(
                serverType: serverType,
                connectionType: .country(serverWrapper.server.countryCode, .server(serverWrapper.server)),
                connectionProtocol: connectionProtocol,
                netShieldType: netShield,
                natType: natType,
                safeMode: safeMode,
                portForwarding: portForwarding,
                profileId: id,
                profileName: name,
                trigger: trigger
            )
        }
    }

    init(
        accessTier: Int,
        profileIcon: ProfileIcon,
        profileType: ProfileType,
        serverType: ServerType,
        serverOffering: ServerOffering,
        name: String,
        connectionProtocol: ConnectionProtocol,
        lastConnectedDate: Date? = nil
    ) {
        let id = String.randomString(length: Profile.idLength)
        self.init(
            id: id,
            accessTier: accessTier,
            profileIcon: profileIcon,
            profileType: profileType,
            serverType: serverType,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: connectionProtocol,
            lastConnectedDate: lastConnectedDate
        )
    }

    func copyWith(newNetShieldType _: NetShieldType) -> Profile {
        Profile(
            id: id,
            accessTier: accessTier,
            profileIcon: profileIcon,
            profileType: profileType,
            serverType: serverType,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: connectionProtocol,
            lastConnectedDate: lastConnectedDate
        )
    }

    func withUpdatedConnectionDate() -> Profile {
        Profile(
            id: id,
            accessTier: accessTier,
            profileIcon: profileIcon,
            profileType: profileType,
            serverType: serverType,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: connectionProtocol,
            lastConnectedDate: Date()
        )
    }

    func withProtocol(_ protocol: ConnectionProtocol) -> Profile {
        Profile(
            id: id,
            accessTier: accessTier,
            profileIcon: profileIcon,
            profileType: profileType,
            serverType: serverType,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: `protocol`
        )
    }
}
