//
//  Created on 31/07/2026 by Chris Janusiewicz.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if os(iOS)
    import Dependencies
    import Foundation
    import OSLog
    import protun

    /// One-time migration for tunnels established by the WireGuard Go extension before ProTUN existed.
    ///
    /// It recovers previous keys and session information, allowing ProTUN to reuse it to fetch a certificate without
    /// relying on the app responding to a fork selector request.
    enum LegacyKeychainMigration {
        /// Service shared by `AuthKeychain` and `VpnAuthenticationStorage` (was `KeychainConstants.appKeychain`).
        private static let service = "ProtonVPN"

        private enum Account: String {
            /// `AuthKeychain.StorageKey.contextKeys[.wireGuardExtension]`
            case wireGuardSession = "authCredentials_wireGuardExtension"
            case vpnKeys
        }

        enum Failure: Error {
            case valueMissing
            case decodingError(Error)
            case encodingError(Error)
        }

        /// Copies whatever legacy session state is present into `cache`, leaving existing entries untouched.
        static func migrateIfNeeded(into cache: SecurePersistentCache, config: ProTUNAdapter.Configuration) throws {
            // Don't migrate a second time (e.g. if the extension has been started without the app for a second time)
            let needsMigration = cache.get(key: .apiSession) == nil || cache.get(key: .privateKey) == nil
            guard needsMigration else {
                Logger.adapter.info("ProTUN cache already populated, skipping legacy keychain migration")
                return
            }

            Logger.adapter.info("Migrating legacy WireGuard session state into the ProTUN cache")

            try migrate(
                .apiSession,
                account: Account.wireGuardSession.rawValue,
                into: cache,
                encode: { (credentials: LegacyAuthCredentials) in
                    try LegacyCacheEncoder.apiSessionBytes(from: credentials, userId: config.userID)
                }
            )
            try migrate(
                .privateKey,
                account: Account.vpnKeys.rawValue,
                into: cache,
                encode: LegacyCacheEncoder.privateKeyBytes(from:)
            )
        }

        private static func migrate<T: Decodable>(
            _ key: CacheKey,
            account: String,
            into cache: SecurePersistentCache,
            encode: (T) throws -> Data
        ) throws(Failure) {
            Logger.adapter.info("Migrating \(key, privacy: .public) from legacy keychain into ProTUN cache")
            guard let decoded = try read(T.self, account: account) else {
                throw .valueMissing
            }

            do {
                let encoded = try encode(decoded)
                cache.put(key: key, bytes: encoded)
                Logger.adapter.info("Migrated \(key, privacy: .public) into the ProTUN cache")
            } catch {
                throw .encodingError(error)
            }
        }

        private static func read<T: Decodable>(_: T.Type, account: String) throws(Failure) -> T? {
            @Dependency(\.lightKeychain) var lightKeychain
            let (status, data) = lightKeychain.getPassword(service: service, account: account)

            guard status == errSecSuccess, let data else {
                throw .valueMissing
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw .encodingError(error)
            }
        }
    }

    /// Translates legacy keychain payloads into the format ProTUN/muon expect
    private enum LegacyCacheEncoder {
        static func apiSessionBytes(from credentials: LegacyAuthCredentials, userId: String) throws -> Data {
            /// The WireGuard Go extension didn't store the userId alongside the token information
            /// While not strictly required by ProTUN/muon, it cannot be empty/nil (indicating an anonymous session)
            let session = APISession(
                internal: .init(
                    userID: userId,
                    uid: credentials.sessionId,
                    tok: .init(access: .init(
                        accessToken: credentials.accessToken,
                        refreshToken: credentials.refreshToken,
                        scopes: credentials.scopes
                    ))
                )
            )

            return try JSONEncoder().encode(session)
        }

        static func privateKeyBytes(from keys: LegacyVPNKeys) -> Data {
            let pem = keys.privateKey.derRepresentation
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Data(pem.utf8)
        }
    }

    /// ProTUN/muon session representation.
    /// Only used during the migration from an existing WG Go extension to continue while the app is in the background
    private struct APISession: Encodable {
        let `internal`: Internal

        struct Internal: Encodable {
            let userID: String
            let uid: String
            let tok: Token

            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case uid
                case tok
            }
        }

        struct Token: Encodable {
            struct Access: Encodable {
                let accessToken: String
                let refreshToken: String
                let scopes: [String]

                enum CodingKeys: String, CodingKey {
                    case accessToken = "acc_tok"
                    case refreshToken = "ref_tok"
                    case scopes
                }
            }

            let access: Access

            enum CodingKeys: String, CodingKey {
                case access = "Access"
            }
        }

        enum CodingKeys: String, CodingKey {
            case `internal` = "Internal"
        }
    }

    /// Subset of `VPNShared.AuthCredentials` that ProTUN/muon needs to smoothly take over a previous WG Go extension's session
    private struct LegacyAuthCredentials: Decodable {
        let accessToken: String
        let refreshToken: String
        let sessionId: String
        let scopes: [String]
    }

    private struct LegacyVPNKeys: Decodable {
        struct PrivateKey: Decodable {
            let derRepresentation: String
        }

        let privateKey: PrivateKey
    }

#endif
