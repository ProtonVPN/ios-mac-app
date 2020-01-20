//
//  AuthCredentials.swift
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

public class AuthCredentials: NSObject, NSCoding {
    
    public enum Scope: String {
        case `self`
        case payments
        case unknown
        
        init(_ string: String) {
            switch string {
            case "self":
                self = .self
            case "payments":
                self = .payments
            default:
                self = .unknown
            }
        }
    }
    
    private let VERSION: Int = 0 //Current build version.
    
    public let cacheVersion: Int //Cached version default is 0
    public let username: String
    public let accessToken: String
    public let refreshToken: String
    public let sessionId: String
    public let userId: String? // introduced in version 1.0.1 iOS, 1.4.0 macOS
    public let expiration: Date
    public let scopes: [Scope]
    
    override public var description: String {
        return
            "Username: \(username)\n" +
            "Access token: \(accessToken)\n" +
            "Refresh token: \(refreshToken)\n" +
            "Session ID: \(sessionId)\n" +
            "User ID: \(userId ?? "<empty>")\n" +
            "Expiration: \(expiration)\n" +
            "Scopes: \(scopes)\n"
    }
    
    public init(version: Int, username: String, accessToken: String, refreshToken: String, sessionId: String, userId: String?, expiration: Date, scopes: [Scope]) {
        self.cacheVersion = version
        self.username = username
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionId = sessionId
        self.userId = userId
        self.expiration = expiration
        self.scopes = scopes
        super.init()
    }
    
    public init(username: String, dic: JSONDictionary) throws {
        self.cacheVersion = self.VERSION
        self.username = username
        accessToken = try dic.stringOrThrow(key: "AccessToken")
        refreshToken = try dic.stringOrThrow(key: "RefreshToken")
        sessionId = try dic.stringOrThrow(key: "UID")
        userId = try dic.stringOrThrow(key: "UserID")
        expiration = try dic.unixTimestampFromNowOrThrow(key: "ExpiresIn")
        let scopeString = try dic.stringOrThrow(key: "Scope")
        scopes = scopeString.components(separatedBy: .whitespaces).map { Scope($0) }
        super.init()
    }
    
    public func updatedWithAccessToken(response: RefreshAccessTokenResponse) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expiration, scopes: scopes)
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let authCacheVersion = "authCacheVersion"
        static let username = "username"
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
        static let sessionId = "userId" // missnamed, should be "sessionId", but leaving for backwards compat
        static let userId = "staticUserId"
        static let expiration = "expiration"
        static let scopes = "scopes"
    }
    
    public required convenience init(coder aDecoder: NSCoder) {
        var scopes: [Scope] = []
        if let scopesData = aDecoder.decodeObject(forKey: CoderKey.scopes) as? Data {
            scopes = (NSKeyedUnarchiver.unarchiveObject(with: scopesData) as? [String] ?? []).map { Scope($0) }
        }
        
        self.init(version: aDecoder.decodeObject(forKey: CoderKey.authCacheVersion) as? Int ?? 0,
                  username: aDecoder.decodeObject(forKey: CoderKey.username) as! String,
                  accessToken: aDecoder.decodeObject(forKey: CoderKey.accessToken) as! String,
                  refreshToken: aDecoder.decodeObject(forKey: CoderKey.refreshToken) as! String,
                  sessionId: aDecoder.decodeObject(forKey: CoderKey.sessionId) as! String,
                  userId: aDecoder.decodeObject(forKey: CoderKey.userId) as? String,
                  expiration: aDecoder.decodeObject(forKey: CoderKey.expiration) as! Date,
                  scopes: scopes)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.VERSION, forKey: CoderKey.authCacheVersion)
        aCoder.encode(username, forKey: CoderKey.username)
        aCoder.encode(accessToken, forKey: CoderKey.accessToken)
        aCoder.encode(refreshToken, forKey: CoderKey.refreshToken)
        aCoder.encode(sessionId, forKey: CoderKey.sessionId)
        aCoder.encode(userId, forKey: CoderKey.userId)
        aCoder.encode(expiration, forKey: CoderKey.expiration)
        
        let scopesData = NSKeyedArchiver.archivedData(withRootObject: scopes.map { $0.rawValue })
        aCoder.encode(scopesData, forKey: CoderKey.scopes)
    }
}
