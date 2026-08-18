//
//  Dictionary+JSONDictionary.swift
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

public typealias JSONDictionary = [String: Any]
public typealias JSONArray = [JSONDictionary]

public extension Dictionary where Key: ExpressibleByStringLiteral {
    subscript<ReturnType>(throwing key: Key) -> ReturnType {
        get throws {
            try valueOrThrow(key)
        }
    }

    // MARK: String

    func string(_ key: Key) -> String? {
        self[key] as? String
    }

    func string(key: Key, orThrow: Error) throws -> String {
        guard let val = string(key) else { throw orThrow }
        return val
    }

    func stringOrThrow(key: Key) throws -> String {
        try valueOrThrow(key)
    }

    func url(key: Key) -> URL? {
        guard let string: String = try? valueOrThrow(key) else { return nil }
        return URL(string: string)
    }

    // MARK: Double

    func doubleOrThrow(key: Key) throws -> Double {
        try valueOrThrow(key)
    }

    // MARK: Int

    func int(key: Key) -> Int? {
        self[key] as? Int
    }

    func intOrThrow(key: Key) throws -> Int {
        try valueOrThrow(key)
    }

    // MARK: Bool

    func bool(_ key: Key) -> Bool? {
        self[key] as? Bool
    }

    func bool(key: Key, or defaultValue: Bool) -> Bool {
        bool(key) ?? defaultValue
    }

    func boolOrThrow(key: Key) throws -> Bool {
        try valueOrThrow(key)
    }

    // MARK: Json

    func jsonArray(key: Key) -> JSONArray? {
        self[key] as? JSONArray
    }

    func jsonDictionary(key: Key) -> JSONDictionary? {
        self[key] as? JSONDictionary
    }

    func jsonDictionaryOrThrow(key: Key) throws -> JSONDictionary {
        try valueOrThrow(key)
    }

    // MARK: - Generic

    func valueOrThrow<T>(_ key: Key) throws -> T {
        guard let val = self[key] as? T else {
            throw genericKeyErrorFor(key)
        }
        return val
    }
}

func genericKeyErrorFor<T: ExpressibleByStringLiteral>(_ key: T) -> Error {
    NSError(domain: "Dictionary", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Dictionary doesn't contain key: \"\(key)\" of type \(T.self)",
    ])
}
