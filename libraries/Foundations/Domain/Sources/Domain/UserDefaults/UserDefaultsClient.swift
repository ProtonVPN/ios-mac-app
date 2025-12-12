//
//  Created on 11/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import Foundation

public struct UserDefaultsClient: DependencyKey, Sendable {
    public var flipBool: @Sendable (UserDefaultsEntry) -> Void
    public var entries: @Sendable () async throws -> [UserDefaultsEntry]
    public var standardEntries: @Sendable () async throws -> [UserDefaultsEntry]
    public var reset: @Sendable () async throws -> Void

    public static let liveValue = UserDefaultsClient(
        flipBool: { entry in
            guard let suiteName = getSuiteName(),
                  let userDefaults = getUserDefaults else {
                return
            }
            guard case let .bool(value) = entry.value else { return }

            userDefaults.set(!value, forKey: entry.key)
        },
        entries: {
            try getPersistentDomain()
                .compactMap { UserDefaultsEntry(key: $0, object: $1) }
                .sorted {
                    $0.key.compare($1.key, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
                }
        },
        standardEntries: {
            let suiteName = Bundle.main.bundleIdentifier
            guard let domain = UserDefaults.standard.persistentDomain(forName: suiteName ?? "") else { return [] }
            return domain
                .compactMap { UserDefaultsEntry(key: $0, object: $1) }
                .sorted {
                    $0.key.compare($1.key, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
                }
        },
        reset: {
            // reset standard user defaults
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            #if os(iOS)
                // reset app suite user defaults. Don't do it on macOS
                guard let suiteName = getSuiteName() else {
                    throw UserDefaultsError.userDefaultsMissing("")
                }
                guard let userDefaults = getUserDefaults else {
                    throw UserDefaultsError.userDefaultsMissing(suiteName)
                }

                userDefaults.removePersistentDomain(forName: suiteName)
            #endif
        }
    )

    static func getPersistentDomain() throws -> [String: Any] {
        guard let suiteName = getSuiteName() else {
            throw UserDefaultsError.userDefaultsMissing("")
        }
        guard let domain = getUserDefaults?.persistentDomain(forName: suiteName) else {
            throw UserDefaultsError.persistentDomainMissing(suiteName)
        }
        return domain
    }

    public static let getUserDefaults: UserDefaults? = {
        #if os(iOS)
            guard let suiteName = getSuiteName(),
                  let defaults = UserDefaults(suiteName: suiteName) else {
                return nil
            }
            return defaults
        #else
            return UserDefaults.standard
        #endif
    }()

    static func getSuiteName() -> String? {
        #if os(iOS)
            DomainConstants.AppGroups.main
        #else
            Bundle.main.bundleIdentifier
        #endif
    }

    enum UserDefaultsError: Error {
        case userDefaultsMissing(String)
        case persistentDomainMissing(String)
    }
}

public extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

public extension UserDefaultsEntry {
    init(key: String, object: Any) {
        self.init(key: key, value: Value(object))
    }
}

public extension UserDefaultsEntry.Value {
    init(_ object: Any) {
        switch object {
        case let string as String:
            self = .string(string)
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .int(int)
        case let data as Data:
            if let utf8 = String(data: data, encoding: .utf8) {
                self = .utf8(utf8)
            } else {
                self = .data(data)
            }
        default:
            self = .unknown("\(object)")
        }
    }
}

public struct UserDefaultsEntry: Equatable, Hashable {
    public let key: String
    public let value: Value

    public enum Value: Equatable, Hashable {
        case string(String)
        case utf8(String)
        case bool(Bool)
        case int(Int)
        case data(Data)
        case unknown(String)
    }
}

public extension UserDefaultsEntry {
    func textValue() -> String {
        switch value {
        case let .bool(boolValue):
            String(boolValue)

        case let .data(data):
            "Data(\(data.count) bytes)"

        case let .int(intValue):
            String(intValue)

        case let .string(string), let .utf8(string), let .unknown(string):
            string.count > 180 ? string.prefix(180) + "... \n\n(\(string.count - 180) more characters)" : string
        }
    }
}
