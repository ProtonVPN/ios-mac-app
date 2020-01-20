//
//  VpnCredentials.swift
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

public class VpnCredentials: NSObject, NSCoding {
    public let status: Int
    public let expirationTime: Date
    public let accountPlan: AccountPlan
    public let maxConnect: Int
    public let maxTier: Int
    public let services: Int
    public let groupId: String
    public let name: String
    public let password: String
    public let delinquent: Int
    
    override public var description: String {
        return
            "Status: \(status)\n" +
            "Expiration time: \(String(describing: expirationTime))\n" +
            "Account plan: \(accountPlan.description)\n" +
            "Max connect: \(maxConnect)\n" +
            "Max tier: \(maxTier)\n" +
            "Services: \(services)\n" +
            "Group ID: \(groupId)\n" +
            "Name: \(name)\n" +
            "Password: \(password)\n" +
            "Delinquent: \(delinquent)\n"
    }
    
    public var hasExpired: Bool {
        return Date().compare(expirationTime) != .orderedAscending
    }
    
    public var isDelinquent: Bool {
        return delinquent > 2
    }
    
    public var serviceName: String {
        var name = LocalizedString.unavailable
        if services & 0b001 != 0 {
            name = "ProtonMail"
        } else if services & 0b100 != 0 {
            name = "ProtonVPN"
        }
        return name
    }
    
    public init(status: Int, expirationTime: Date, accountPlan: AccountPlan, maxConnect: Int, maxTier: Int, services: Int, groupId: String, name: String, password: String, delinquent: Int) {
        self.status = status
        self.expirationTime = expirationTime
        self.accountPlan = accountPlan
        self.maxConnect = maxConnect
        self.maxTier = maxTier
        self.services = services
        self.groupId = groupId
        self.name = name
        self.password = password
        self.delinquent = delinquent
        super.init()
    }
    
    init(dic: JSONDictionary) throws {
        let vpnDic = try dic.jsonDictionaryOrThrow(key: "VPN")
        
        status = try vpnDic.intOrThrow(key: "Status")
        
        if status != 1 {
            if status == 0 {
                throw ProtonVpnErrorConst.userHasNoVpnAccess
            } else if status == 2 {
                throw ProtonVpnErrorConst.userHasNotSignedUp
            } else {
                throw ProtonVpnErrorConst.userIsOnWaitlist
            }
        }
        
        expirationTime = try vpnDic.unixTimestampOrThrow(key: "ExpirationTime")
        accountPlan = AccountPlan(planName: try vpnDic.stringOrThrow(key: "PlanName"))
        maxConnect = try vpnDic.intOrThrow(key: "MaxConnect")
        maxTier = try vpnDic.intOrThrow(key: "MaxTier")
        services = try dic.intOrThrow(key: "Services")
        groupId = try vpnDic.stringOrThrow(key: "GroupID")
        name = try vpnDic.stringOrThrow(key: "Name")
        password = try vpnDic.stringOrThrow(key: "Password")
        delinquent = try dic.intOrThrow(key: "Delinquent")
        super.init()
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let status = "status"
        static let expirationTime = "expirationTime"
        static let accountPlan = "accountPlan"
        static let maxConnect = "maxConnect"
        static let maxTier = "maxTier"
        static let services = "services"
        static let groupId = "groupId"
        static let name = "name"
        static let password = "password"
        static let delinquent = "delinquent"
    }
    
    public required convenience init(coder aDecoder: NSCoder) {
        self.init(status: aDecoder.decodeInteger(forKey: CoderKey.status),
                  expirationTime: aDecoder.decodeObject(forKey: CoderKey.expirationTime) as! Date,
                  accountPlan: AccountPlan(coder: aDecoder),
                  maxConnect: aDecoder.decodeInteger(forKey: CoderKey.maxConnect),
                  maxTier: aDecoder.decodeInteger(forKey: CoderKey.maxTier),
                  services: aDecoder.decodeInteger(forKey: CoderKey.services),
                  groupId: aDecoder.decodeObject(forKey: CoderKey.groupId) as! String,
                  name: aDecoder.decodeObject(forKey: CoderKey.name) as! String,
                  password: aDecoder.decodeObject(forKey: CoderKey.password) as! String,
                  delinquent: aDecoder.decodeInteger(forKey: CoderKey.delinquent))
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(status, forKey: CoderKey.status)
        aCoder.encode(expirationTime, forKey: CoderKey.expirationTime)
        accountPlan.encode(with: aCoder)
        aCoder.encode(maxConnect, forKey: CoderKey.maxConnect)
        aCoder.encode(maxTier, forKey: CoderKey.maxTier)
        aCoder.encode(services, forKey: CoderKey.services)
        aCoder.encode(groupId, forKey: CoderKey.groupId)
        aCoder.encode(name, forKey: CoderKey.name)
        aCoder.encode(password, forKey: CoderKey.password)
        aCoder.encode(delinquent, forKey: CoderKey.delinquent)
    }
}
