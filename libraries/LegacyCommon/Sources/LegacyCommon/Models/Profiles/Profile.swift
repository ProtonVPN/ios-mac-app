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

import Domain
import VPNShared
import VPNAppCore

public class Profile: NSObject, NSCoding, Identifiable, Codable {

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
    
    override public var description: String {
        return
            "ID: \(id)\n" +
            "Access tier: \(accessTier)\n" +
            "Profile icon: \(profileIcon.description)\n" +
            "Profile type: \(profileType.description)\n" +
            "Server type: \(serverType.description)\n" +
            "Server offering: \(serverOffering.description)\n" +
            "Name: \(name)\n" +
            "Protocol: \(connectionProtocol)\n" +
            "Last connected date: \(lastConnectedDate?.description ?? "None")"
    }
    
    public var logDescription: String {
        return
            "ID: \(id) " +
            "Access tier: \(accessTier) " +
            "Profile icon: \(profileIcon.description) " +
            "Profile type: \(profileType.description) " +
            "Server type: \(serverType.description) " +
            "Server offering: \(serverOffering.description) " +
            "Name: \(name) " +
            "Protocol: \(connectionProtocol) " +
            "Last connected date: \(lastConnectedDate?.description ?? "None")"
    }

    public var isDefaultProfile: Bool {
        ProfileConstants.defaultIds.contains(id)
    }

    public func connectionRequest(withDefaultNetshield netShield: NetShieldType, withDefaultNATType natType: NATType, withDefaultSafeMode safeMode: Bool?, trigger: ConnectionDimensions.VPNTrigger?) -> ConnectionRequest {
        switch serverOffering {
        case let .fastest(countryCode):
            let connectionType: ConnectionRequestType = countryCode.flatMap({ ConnectionRequestType.country($0, .fastest) }) ?? ConnectionRequestType.fastest
            return ConnectionRequest(serverType: serverType, connectionType: connectionType, connectionProtocol: connectionProtocol, netShieldType: netShield, natType: natType, safeMode: safeMode, profileId: id, trigger: trigger)
        case let .random(countryCode):
            let connectionType: ConnectionRequestType = countryCode.flatMap({ ConnectionRequestType.country($0, .random) }) ?? ConnectionRequestType.random
            return ConnectionRequest(serverType: serverType, connectionType: connectionType, connectionProtocol: connectionProtocol, netShieldType: netShield, natType: natType, safeMode: safeMode, profileId: id, trigger: trigger)
        case let .custom(serverWrapper):
            return ConnectionRequest(serverType: serverType, connectionType: .country(serverWrapper.server.countryCode, .server(serverWrapper.server)), connectionProtocol: connectionProtocol, netShieldType: netShield, natType: natType, safeMode: safeMode, profileId: id, trigger: trigger)
        }
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
    
    public convenience init(
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

    // MARK: - NSCoding
    private struct CoderKey {
        static let id = "id"
        static let accessTier = "accessTier"
        static let name = "name"
        static let connectionProtocol = "connectionProtocol"
        static let lastConnectedDate = "lastConnectedDate"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        let id = aDecoder.decodeObject(forKey: CoderKey.id) as! String
        let accessTier = aDecoder.decodeInteger(forKey: CoderKey.accessTier)
        let profileIcon = ProfileIcon(coder: aDecoder)
        let profileType = ProfileType(coder: aDecoder)
        let serverType = ServerType(coder: aDecoder)
        let serverOffering = ServerOffering(coder: aDecoder)
        let name = aDecoder.decodeObject(forKey: CoderKey.name) as! String
        let timestamp = aDecoder.decodeObject(forKey: CoderKey.lastConnectedDate) as? Double

        var date: Date?
        if let timestamp {
            date = Date(timeIntervalSince1970: timestamp)
        }

        // old version data
        if let vpnProtocol = VpnProtocol(coder: aDecoder) {
            self.init(
                id: id,
                accessTier: accessTier,
                profileIcon: profileIcon,
                profileType: profileType,
                serverType: serverType,
                serverOffering: serverOffering,
                name: name,
                connectionProtocol: .vpnProtocol(vpnProtocol),
                lastConnectedDate: date
            )
            return
        }

        let connectionProtocolCodingValue = aDecoder.decodeInteger(forKey: CoderKey.connectionProtocol)
        self.init(
            id: id,
            accessTier: accessTier,
            profileIcon: profileIcon,
            profileType: profileType,
            serverType: serverType,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: ConnectionProtocol.from(codingValue: connectionProtocolCodingValue) ?? .vpnProtocol(.defaultValue),
            lastConnectedDate: date
        )
    }
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
    
    public func copyWith(newNetShieldType type: NetShieldType) -> Profile {
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

    public func withUpdatedConnectionDate() -> Profile {
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

    public func withProtocol(_ `protocol`: ConnectionProtocol) -> Profile {
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

fileprivate extension ConnectionProtocol {
    static func from(codingValue: Int) -> ConnectionProtocol? {
        switch codingValue {
        case 0:
            return .smartProtocol
        case 1:
            return .vpnProtocol(.ike)
        case 2:
            return .vpnProtocol(.openVpn(.udp))
        case 3:
            return .vpnProtocol(.openVpn(.tcp))
        case 4:
            return .vpnProtocol(.wireGuard(.udp))
        case 5:
            return .vpnProtocol(.wireGuard(.tcp))
        case 6:
            return .vpnProtocol(.wireGuard(.tls))
        default:
            return nil
        }
    }
}
