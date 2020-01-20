//
//  ServerIp.swift
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

public  class ServerIp: NSObject, NSCoding {
    public let id: String //"ID": "l8vWAXHBQNSQjPrxAr-D_BCxj1X0nW70HQRmAa-rIvzmKUA=="
    public let entryIp: String //"EntryIP": "95.215.61.163"
    public let exitIp: String //"ExitIP": "95.215.61.164"
    public let domain: String  //"Domain": "es-04.protonvpn.com"
    public let status: Int //"Status": 1  (1 - OK, 0 - under maintenance)
    public var hasExistingSession: Bool = false
    
    override public var description: String {
        return
            "ID      = \(id)\n" +
                "EntryIP = \(entryIp)\n" +
                "ExitIP  = \(exitIp)\n" +
                "Domain  = \(domain)\n" +
        "Status  = \(status)\n"
    }
    
    public init(id: String, entryIp: String, exitIp: String, domain: String, status: Int) {
        self.id = id
        self.entryIp = entryIp
        self.exitIp = exitIp
        self.domain = domain
        self.status = status
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        self.id = try dic.stringOrThrow(key: "ID")
        self.entryIp = try dic.stringOrThrow(key: "EntryIP")
        self.exitIp = try dic.stringOrThrow(key: "ExitIP")
        self.domain = try dic.stringOrThrow(key: "Domain")
        self.status = try dic.intOrThrow(key: "Status")
        super.init()
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let ID = "IDKey"
        static let entryIp = "entryIpKey"
        static let exitIp = "exitIpKey"
        static let domain = "domainKey"
        static let status = "statusKey"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: CoderKey.ID) as? String,
            let entryIp = aDecoder.decodeObject(forKey: CoderKey.entryIp) as? String,
            let exitIp = aDecoder.decodeObject(forKey: CoderKey.exitIp) as? String,
            let domain = aDecoder.decodeObject(forKey: CoderKey.domain) as? String else {
                return nil
        }
        let status = aDecoder.decodeInteger(forKey: CoderKey.status)
        self.init(id: id, entryIp: entryIp, exitIp: exitIp, domain: domain, status: status)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.ID)
        aCoder.encode(entryIp, forKey: CoderKey.entryIp)
        aCoder.encode(exitIp, forKey: CoderKey.exitIp)
        aCoder.encode(domain, forKey: CoderKey.domain)
        aCoder.encode(status, forKey: CoderKey.status)
    }
    
    public var underMaintenance: Bool {
        return status == 0
    }
    
    // MARK: - Static functions
    
    // swiftlint:disable nsobject_prefer_isequal
    public static func == (lhs: ServerIp, rhs: ServerIp) -> Bool {
        return lhs.domain == rhs.domain
    }
    // swiftlint:enable nsobject_prefer_isequal
    
}
