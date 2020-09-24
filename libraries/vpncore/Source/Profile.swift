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

public class Profile: NSObject, NSCoding {

    public static let idLength = 20

    public let id: String
    public let accessTier: Int
    public let profileIcon: ProfileIcon
    public let profileType: ProfileType
    public let serverType: ServerType
    public let serverOffering: ServerOffering
    public let name: String
    public let vpnProtocol: VpnProtocol
    public let netShieldType: NetShieldType?
    
    override public var description: String {
        return
            "ID: \(id)\n" +
            "Access tier: \(accessTier)\n" +
            "Profile icon: \(profileIcon.description)\n" +
            "Profile type: \(profileType.description)\n" +
            "Server type: \(serverType.description)\n" +
            "Server offering: \(serverOffering.description)\n" +
            "Name: \(name)\n" +
            "Protocol: \(vpnProtocol)\n" +
            "NetShieldType: \(String(describing: netShieldType))\n"
    }
    
    public func connectionRequest(withDefaultNetshield defaultNetshield: NetShieldType) -> ConnectionRequest {
        let netShield = netShieldType ?? defaultNetshield
        
        switch serverOffering {
        case .fastest(let cCode):
            if let cCode = cCode {
                return ConnectionRequest(serverType: serverType, connectionType: .country(cCode, .fastest), vpnProtocol: vpnProtocol, netShieldType: netShield, profileId: id)
            } else {
                return ConnectionRequest(serverType: serverType, connectionType: .fastest, vpnProtocol: vpnProtocol, netShieldType: netShield, profileId: id)
            }
        case .random(let cCode):
            if let cCode = cCode {
                return ConnectionRequest(serverType: serverType, connectionType: .country(cCode, .random), vpnProtocol: vpnProtocol, netShieldType: netShield, profileId: id)
            } else {
                return ConnectionRequest(serverType: serverType, connectionType: .random, vpnProtocol: vpnProtocol, netShieldType: netShield, profileId: id)
            }
        case .custom(let sWrapper):
            return ConnectionRequest(serverType: serverType, connectionType: .country(sWrapper.server.countryCode, .server(sWrapper.server)), vpnProtocol: vpnProtocol, netShieldType: netShield, profileId: id)
        }
    }
    
    public init(id: String, accessTier: Int, profileIcon: ProfileIcon, profileType: ProfileType, serverType: ServerType, serverOffering: ServerOffering, name: String, vpnProtocol: VpnProtocol?, netShieldType: NetShieldType?) {
        self.id = id
        self.accessTier = accessTier
        self.profileIcon = profileIcon
        self.profileType = profileType
        self.serverType = serverType
        self.serverOffering = serverOffering
        self.name = name
        self.vpnProtocol = vpnProtocol ?? .ike
        self.netShieldType = netShieldType
    }
    
    public convenience init(accessTier: Int, profileIcon: ProfileIcon, profileType: ProfileType, serverType: ServerType, serverOffering: ServerOffering, name: String, vpnProtocol: VpnProtocol?, netShieldType: NetShieldType?) {
        let id = String.randomString(length: Profile.idLength)
        self.init(id: id, accessTier: accessTier, profileIcon: profileIcon, profileType: profileType,
                  serverType: serverType, serverOffering: serverOffering, name: name, vpnProtocol: vpnProtocol, netShieldType: netShieldType)
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let id = "id"
        static let accessTier = "accessTier"
        static let name = "name"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        self.init(id: aDecoder.decodeObject(forKey: CoderKey.id) as! String,
                  accessTier: aDecoder.decodeInteger(forKey: CoderKey.accessTier),
                  profileIcon: ProfileIcon(coder: aDecoder),
                  profileType: ProfileType(coder: aDecoder),
                  serverType: ServerType(coder: aDecoder),
                  serverOffering: ServerOffering(coder: aDecoder),
                  name: aDecoder.decodeObject(forKey: CoderKey.name) as! String,
                  vpnProtocol: VpnProtocol(coder: aDecoder),
                  netShieldType: NetShieldType.decodeIfPresent(coder: aDecoder)
        )
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.id)
        aCoder.encode(accessTier, forKey: CoderKey.accessTier)
        profileIcon.encode(with: aCoder)
        profileType.encode(with: aCoder)
        serverType.encode(with: aCoder)
        serverOffering.encode(with: aCoder)
        aCoder.encode(name, forKey: CoderKey.name)
        vpnProtocol.encode(with: aCoder)
        if let netShieldType = netShieldType {
            netShieldType.encode(with: aCoder)
        }
    }
}
