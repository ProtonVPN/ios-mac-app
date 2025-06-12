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
import Domain

struct UserDefaultsClient: DependencyKey, Sendable {
    var entries: @Sendable () async throws -> [UserDefaultsEntry]
    var reset: @Sendable () async throws -> Void

    static let liveValue = UserDefaultsClient(
        entries: {
            try getPersistentDomain()
                .compactMap { UserDefaultsEntry(key: $0, object: $1) }
                .sorted { $0.key < $1.key }
        },
        reset: {
            try getUserDefaults().removePersistentDomain(forName: getSuiteName())
        }
    )

    static func getPersistentDomain() throws -> [String: Any] {
        let suiteName = try getSuiteName()
        guard let domain = try getUserDefaults().persistentDomain(forName: suiteName) else {
            throw UserDefaultsError.persistentDomainMissing(suiteName)
        }
        return domain
    }

    static func getUserDefaults() throws -> UserDefaults {
#if os(iOS)
        let suiteName = try getSuiteName()
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw UserDefaultsError.userDefaultsMissing(suiteName)
        }
        return defaults
#elseif os(macOS)
        return UserDefaults.standard
#endif
    }

    static func getSuiteName() throws -> String {
#if os(iOS)
        return DomainConstants.AppGroups.main
#elseif os(macOS)
        guard let suiteName = Bundle.main.bundleIdentifier else {
            fatalError()
        }
        return suiteName
#endif
    }

    enum UserDefaultsError: Error {
        case userDefaultsMissing(String)
        case persistentDomainMissing(String)
    }
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

extension UserDefaultsEntry {
    public init(key: String, object: Any) {
        self.init(key: key, value: Value(object))
    }
}

extension UserDefaultsEntry.Value {
    public init(_ object: Any) {
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
