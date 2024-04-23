//
//  AuthCredentials.swift
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

import Ergonomics

public class AuthCredentials: NSObject, NSSecureCoding, Codable {
    static let VERSION: Int = 0 // Current build version.

    public static var supportsSecureCoding: Bool = true
    
    public let cacheVersion: Int // Cached version default is 0
    public let username: String
    public let accessToken: String
    public let refreshToken: String
    public let sessionId: String
    public let userId: String? // introduced in version 1.0.1 iOS, 1.4.0 macOS
    public let scopes: [String]
    
    override public var description: String {
        return
            "Username: \(username)\n" +
            "Access token: \(accessToken)\n" +
            "Refresh token: \(refreshToken)\n" +
            "Session ID: \(sessionId)\n" +
            "User ID: \(userId ?? "<empty>")\n" +
            "Scopes: \(scopes)\n"
    }
    
    public init(version: Int? = nil, username: String, accessToken: String, refreshToken: String, sessionId: String, userId: String?, scopes: [String]) {
        self.cacheVersion = version ?? Self.VERSION
        self.username = username
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionId = sessionId
        self.userId = userId
        self.scopes = scopes
        super.init()
    }
    
    public init(username: String, dic: JSONDictionary) throws {
        self.cacheVersion = Self.VERSION
        self.username = username
        accessToken = try dic.stringOrThrow(key: "AccessToken")
        refreshToken = try dic.stringOrThrow(key: "RefreshToken")
        sessionId = try dic.stringOrThrow(key: "UID")
        userId = try dic.stringOrThrow(key: "UserID")
        let scopeString = try dic.stringOrThrow(key: "Scope")
        scopes = scopeString.components(separatedBy: .whitespaces)
        super.init()
    }
        
    // MARK: - NSCoding
    private struct CoderKey {
        static let authCacheVersion = "authCacheVersion"
        static let username = "username"
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
        static let sessionId = "userId" // misnamed, should be "sessionId", but leaving for backwards compatibility
        static let userId = "staticUserId"
        static let scopes = "scopes"
    }
    
    public required convenience init(coder aDecoder: NSCoder) {
        var scopes: [String] = []
        if let scopesData = aDecoder.decodeObject(forKey: CoderKey.scopes) as? Data,
           let unarchivedScopes = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self], from: scopesData) {
            scopes = unarchivedScopes as? [String] ?? []
        }
        
        self.init(version: aDecoder.decodeInteger(forKey: CoderKey.authCacheVersion),
                  username: aDecoder.decodeObject(of: NSString.self, forKey: CoderKey.username)! as String,
                  accessToken: aDecoder.decodeObject(of: NSString.self, forKey: CoderKey.accessToken)! as String,
                  refreshToken: aDecoder.decodeObject(of: NSString.self, forKey: CoderKey.refreshToken)! as String,
                  sessionId: aDecoder.decodeObject(of: NSString.self, forKey: CoderKey.sessionId)! as String,
                  userId: aDecoder.decodeObject(of: NSString.self, forKey: CoderKey.userId) as String?,
                  scopes: scopes)
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
