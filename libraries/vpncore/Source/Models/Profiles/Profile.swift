//
//  Profile.swift
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
import VPNShared

public class Profile: NSObject, NSCoding {

    public static let idLength = 20

    public let id: String
    public let accessTier: Int
    public let profileIcon: ProfileIcon
    public let profileType: ProfileType
    public let serverType: ServerType
    public let serverOffering: ServerOffering
    public let name: String
    public let connectionProtocol: ConnectionProtocol
    
    override public var description: String {
        return
            "ID: \(id)\n" +
            "Access tier: \(accessTier)\n" +
            "Profile icon: \(profileIcon.description)\n" +
            "Profile type: \(profileType.description)\n" +
            "Server type: \(serverType.description)\n" +
            "Server offering: \(serverOffering.description)\n" +
            "Name: \(name)\n" +
            "Protocol: \(connectionProtocol)\n"
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
            "Protocol: \(connectionProtocol) "
    }
    
    public func connectionRequest(withDefaultNetshield netShield: NetShieldType, withDefaultNATType natType: NATType, withDefaultSafeMode safeMode: Bool?, trigger: TelemetryDimensions.VPNTrigger) -> ConnectionRequest {
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
    
    public init(id: String, accessTier: Int, profileIcon: ProfileIcon, profileType: ProfileType, serverType: ServerType, serverOffering: ServerOffering, name: String, connectionProtocol: ConnectionProtocol) {
        self.id = id
        self.accessTier = accessTier
        self.profileIcon = profileIcon
        self.profileType = profileType
        self.serverType = serverType
        self.serverOffering = serverOffering
        self.name = name
        self.connectionProtocol = connectionProtocol
    }
    
    public convenience init(accessTier: Int, profileIcon: ProfileIcon, profileType: ProfileType, serverType: ServerType, serverOffering: ServerOffering, name: String, connectionProtocol: ConnectionProtocol) {
        let id = String.randomString(length: Profile.idLength)
        self.init(id: id, accessTier: accessTier, profileIcon: profileIcon, profileType: profileType,
                  serverType: serverType, serverOffering: serverOffering, name: name, connectionProtocol: connectionProtocol)
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let id = "id"
        static let accessTier = "accessTier"
        static let name = "name"
        static let connectionProtocol = "connectionProtocol"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        let id = aDecoder.decodeObject(forKey: CoderKey.id) as! String
        let accessTier = aDecoder.decodeInteger(forKey: CoderKey.accessTier)
        let profileIcon = ProfileIcon(coder: aDecoder)
        let profileType = ProfileType(coder: aDecoder)
        let serverType = ServerType(coder: aDecoder)
        let serverOffering = ServerOffering(coder: aDecoder)
        let name = aDecoder.decodeObject(forKey: CoderKey.name) as! String

        // old version data
        if let vpnProtocol = VpnProtocol(coder: aDecoder) {
            self.init(id: id, accessTier: accessTier, profileIcon: profileIcon, profileType: profileType, serverType: serverType, serverOffering: serverOffering, name: name, connectionProtocol: .vpnProtocol(vpnProtocol))
            return
        }

        let connectionProtocolCodingValue = aDecoder.decodeInteger(forKey: CoderKey.connectionProtocol)
        self.init(id: id, accessTier: accessTier, profileIcon: profileIcon, profileType: profileType, serverType: serverType, serverOffering: serverOffering, name: name, connectionProtocol: ConnectionProtocol.from(codingValue: connectionProtocolCodingValue) ?? .vpnProtocol(DefaultConstants.vpnProtocol))
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.id)
        aCoder.encode(accessTier, forKey: CoderKey.accessTier)
        profileIcon.encode(with: aCoder)
        profileType.encode(with: aCoder)
        serverType.encode(with: aCoder)
        serverOffering.encode(with: aCoder)
        aCoder.encode(name, forKey: CoderKey.name)
        aCoder.encode(connectionProtocol.codingValue, forKey: CoderKey.connectionProtocol)
    }
    
    public func copyWith(newNetShieldType type: NetShieldType) -> Profile {
        return Profile(id: self.id,
                       accessTier: self.accessTier,
                       profileIcon: self.profileIcon,
                       profileType: self.profileType,
                       serverType: self.serverType,
                       serverOffering: self.serverOffering,
                       name: self.name,
                       connectionProtocol: self.connectionProtocol
                       )
    }
}

fileprivate extension ConnectionProtocol {
    var codingValue: Int {
        switch self {
        case .smartProtocol:
            return 0
        case let .vpnProtocol(vpnProtocol):
            switch vpnProtocol {
            case .ike:
                return 1
            case .openVpn(.udp):
                return 2
            case .openVpn(.tcp):
                return 3
            case .wireGuard(.udp):
                return 4
            case .wireGuard(.tcp):
                return 5
            case .wireGuard(.tls):
                return 6
            }
        }
    }

    static func from(codingValue: Int) -> ConnectionProtocol? {
        switch codingValue {
        case 0:
            return .smartProtocol
        case 1:
            return .vpnProtocol(.ike)
        case 2:
            return .vpnProtocol(.openVpn(.udp))
        case 3:
            return vpnProtocol(.openVpn(.tcp))
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
