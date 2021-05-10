//
//  Dictionary+Extension.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public typealias JSONDictionary = [String: AnyObject]
public typealias JSONArray = [JSONDictionary]

extension Dictionary where Key: ExpressibleByStringLiteral, Value: AnyObject {
    
    // MARK: String
    public func string(_ key: Key) -> String? {
        return self[key] as? String
    }
    
    public func string(key: Key, orThrow: Error) throws -> String {
        guard let val = string(key) else { throw orThrow }
        return val
    }
    
    public func stringOrThrow(key: Key) throws -> String {
        return try valueOrThrow(key)
    }
    
    // MARK: Double
    public func double(_ key: Key) -> Double? {
        return self[key] as? Double
    }
    
    public func doubleOrThrow(key: Key) throws -> Double {
        return try valueOrThrow(key)
    }
    
    // MARK: Int
    public func int(key: Key) -> Int? {
        return self[key] as? Int
    }
    
    public func intOrThrow(key: Key) throws -> Int {
        return try valueOrThrow(key)
    }
    
    // MARK: Bool
    public func bool(_ key: Key) -> Bool? {
        return self[key] as? Bool
    }
    
    public func bool(key: Key, or defaultValue: Bool) -> Bool {
        return bool(key) ?? defaultValue
    }
    
    public func boolOrThrow(key: Key) throws -> Bool {
        return try valueOrThrow(key)
    }
    
    // MARK: Date
    public func unixTimestamp(_ key: Key) -> Date? {
        guard let timestamp = double(key) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    public func unixTimestampOrThrow(key: Key) throws -> Date {
        guard let date = unixTimestamp(key) else {
            throw genericKeyErrorFor(key)
        }
        return date
    }
    
    public func unixTimestampFromNow(_ key: Key) -> Date? {
        guard let timestamp = double(key) else {
            return nil
        }
        return Date(timeIntervalSinceNow: timestamp)
    }
    
    public func unixTimestampFromNowOrThrow(key: Key) throws -> Date {
        guard let date = unixTimestampFromNow(key) else {
            throw genericKeyErrorFor(key)
        }
        return date
    }
    
    // MARK: - Array
    public func stringArray(key: Key) -> [String]? {
        return self[key] as? [String]
    }
    
    public func stringArrayOrThrow(key: Key) throws -> [String] {
        return try valueOrThrow(key)
    }
    
    // MARK: Json
    public func jsonArray(key: Key) -> JSONArray? {
        return self[key] as? JSONArray
    }
    
    public func jsonArrayOrThrow(key: Key) throws -> JSONArray {
        return try valueOrThrow(key)
    }
    
    public func jsonDictionary(key: Key) -> JSONDictionary? {
        return self[key] as? JSONDictionary
    }
    
    public func jsonDictionaryOrThrow(key: Key) throws -> JSONDictionary {
        return try valueOrThrow(key)
    }
    
    // MARK: - Misc
    public func stringOrDoubleAsString(key: Key) -> String? {
        if let str = string(key) { return str }
        if let double = double(key) { return String(double) }
        
        return nil
    }
    
    public func anyAsString(key: Key) -> String? {
        if let val = self[key] {
            return "\(val)"
        }
        return nil
    }
    
    // MARK: - Generic
    public func valueOrThrow<T>(_ key: Key) throws -> T {
        guard let val = self[key] as? T else {
            throw genericKeyErrorFor(key)
        }
        return val
    }
}

func genericKeyErrorFor<T: ExpressibleByStringLiteral>(_ key: T) -> Error {
    return NSError(domain: "Dictionary", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Dictionary doesn't contain key: \"\(key)\" of type \(T.self)"
    ])
}
