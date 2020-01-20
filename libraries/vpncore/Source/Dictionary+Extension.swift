//
//  Dictionary+Extension.swift
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

public typealias JSONDictionary = [String: AnyObject]
public typealias JSONArray = [JSONDictionary]

public extension Dictionary where Key: ExpressibleByStringLiteral, Value: AnyObject {
    
    // MARK: String
    func string(_ key: Key) -> String? {
        return self[key] as? String
    }
    
    func string(key: Key, orThrow: Error) throws -> String {
        guard let val = string(key) else { throw orThrow }
        return val
    }
    
    func stringOrThrow(key: Key) throws -> String {
        return try valueOrThrow(key)
    }
    
    // MARK: Double
    func double(_ key: Key) -> Double? {
        return self[key] as? Double
    }
    
    func doubleOrThrow(key: Key) throws -> Double {
        return try valueOrThrow(key)
    }
    
    // MARK: Int
    func int(key: Key) -> Int? {
        return self[key] as? Int
    }
    
    func intOrThrow(key: Key) throws -> Int {
        return try valueOrThrow(key)
    }
    
    // MARK: Bool
    func bool(_ key: Key) -> Bool? {
        return self[key] as? Bool
    }
    
    func bool(key: Key, or defaultValue: Bool) -> Bool {
        return bool(key) ?? defaultValue
    }
    
    func boolOrThrow(key: Key) throws -> Bool {
        return try valueOrThrow(key)
    }
    
    // MARK: Date
    func unixTimestamp(_ key: Key) -> Date? {
        guard let timestamp = double(key) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    func unixTimestampOrThrow(key: Key) throws -> Date {
        guard let date = unixTimestamp(key) else {
            throw genericKeyErrorFor(key)
        }
        return date
    }
    
    func unixTimestampFromNow(_ key: Key) -> Date? {
        guard let timestamp = double(key) else {
            return nil
        }
        return Date(timeIntervalSinceNow: timestamp)
    }
    
    func unixTimestampFromNowOrThrow(key: Key) throws -> Date {
        guard let date = unixTimestampFromNow(key) else {
            throw genericKeyErrorFor(key)
        }
        return date
    }
    
    // MARK: - Array
    func stringArray(key: Key) -> [String]? {
        return self[key] as? [String]
    }
    
    func stringArrayOrThrow(key: Key) throws -> [String] {
        return try valueOrThrow(key)
    }
    
    // MARK: Json
    func jsonArray(key: Key) -> JSONArray? {
        return self[key] as? JSONArray
    }
    
    func jsonArrayOrThrow(key: Key) throws -> JSONArray {
        return try valueOrThrow(key)
    }
    
    func jsonDictionary(key: Key) -> JSONDictionary? {
        return self[key] as? JSONDictionary
    }
    
    func jsonDictionaryOrThrow(key: Key) throws -> JSONDictionary {
        return try valueOrThrow(key)
    }
    
    // MARK: - Misc
    func stringOrDoubleAsString(key: Key) -> String? {
        if let str = string(key) { return str }
        if let double = double(key) { return String(double) }
        
        return nil
    }
    
    func anyAsString(key: Key) -> String? {
        if let val = self[key] {
            return "\(val)"
        }
        return nil
    }
    
    // MARK: - Generic
    func valueOrThrow<T>(_ key: Key) throws -> T {
        guard let val = self[key] as? T else {
            throw genericKeyErrorFor(key)
        }
        return val
    }
}

internal func genericKeyErrorFor<T: ExpressibleByStringLiteral>(_ key: T) -> Error {
    return NSError(domain: "Dictionary", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Dictionary doesn't contain key: \"\(key)\" of type \(T.self)"
    ])
}
