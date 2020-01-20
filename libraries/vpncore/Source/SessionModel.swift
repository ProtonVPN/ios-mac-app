//
//  SessionModel.swift
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

public class SessionModel: NSObject, NSCoding {
    
    public enum VpnProtocol: String {
        case ikev2
        case openvpn
        case other
    }
    
    public let sessionId: String
    public let exitIp: String
    public let vpnProtocol: VpnProtocol
    
    override public var description: String {
        return
            "SessionID: \(sessionId)\n" +
            "ExitIP: \(exitIp)\n" +
            "Protocol: \(vpnProtocol.rawValue)"
    }
    
    public init(sessionId: String, exitIp: String, vpnProtocol: VpnProtocol) {
        self.sessionId = sessionId
        self.exitIp = exitIp
        self.vpnProtocol = vpnProtocol
        super.init()
    }
    
    internal init(dic: JSONDictionary) throws {
        sessionId = try dic.stringOrThrow(key: "SessionID") //"SessionID": "ABC"
        exitIp = try dic.stringOrThrow(key: "ExitIP") //"ExitIP": "192.2.3.4"
        vpnProtocol = VpnProtocol(rawValue: try dic.stringOrThrow(key: "Protocol")) ?? .other //"Protocol": "ikev2"
        super.init()
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let sessionId = "sessionId"
        static let exitIp = "exitIp"
        static let vpnProtocol = "vpnProtocol"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let sessionId = aDecoder.decodeObject(forKey: CoderKey.sessionId) as? String,
              let exitIp = aDecoder.decodeObject(forKey: CoderKey.exitIp) as? String,
              let vpnProtocolString = aDecoder.decodeObject(forKey: CoderKey.vpnProtocol) as? String,
              let vpnProtocol = VpnProtocol(rawValue: vpnProtocolString)
        else {
            let error = ProtonVpnError.decode(location: "SessionModel")
            PMLog.D("Failed to decode SessionModel", level: .error)
            PMLog.ET(error.localizedDescription)
            return nil
        }
        
        self.init(sessionId: sessionId, exitIp: exitIp, vpnProtocol: vpnProtocol)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(sessionId, forKey: CoderKey.sessionId)
        aCoder.encode(exitIp, forKey: CoderKey.exitIp)
        aCoder.encode(vpnProtocol.rawValue, forKey: CoderKey.vpnProtocol)
    }
}
