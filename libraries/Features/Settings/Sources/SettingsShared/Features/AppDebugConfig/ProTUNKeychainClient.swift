//
//  Created on 06/08/2026 by Chris Janusiewicz.
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

#if DEBUG
    import Dependencies
    import Foundation

    // Debug-only inspector for the ProTUN extension's `SecurePersistentCache`, kept next to its only consumer.
    struct ProTUNKeychainClient: DependencyKey, Sendable {
        /// One cache per user ID, sorted by service.
        var caches: @Sendable () -> [ProTUNCache]
        var clear: @Sendable () -> Void

        static let liveValue = ProTUNKeychainClient(
            caches: {
                Dictionary(grouping: cacheItems()) { $0[kSecAttrService] as? String ?? "" }
                    .map { service, items in
                        ProTUNCache(
                            service: service,
                            entries: items
                                .map { item in
                                    let bytes = item[kSecValueData] as? Data ?? Data()
                                    return ProTUNCache.Entry(
                                        account: item[kSecAttrAccount] as? String ?? "—",
                                        byteCount: bytes.count,
                                        decodedValue: decode(bytes)
                                    )
                                }
                                .sorted { $0.account < $1.account }
                        )
                    }
                    .sorted { $0.service < $1.service }
            },
            clear: {
                for service in Set(cacheItems().compactMap { $0[kSecAttrService] as? String }) {
                    SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
                }
            }
        )

        static let testValue = ProTUNKeychainClient(caches: { [] }, clear: {})

        private static func cacheItems() -> [[CFString: Any]] {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecReturnAttributes: true,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitAll,
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let items = result as? [[CFString: Any]] else { return [] }

            return items.filter { ($0[kSecAttrService] as? String)?.hasPrefix(servicePrefix) == true }
        }

        /// `apiSession` is JSON, `certificate` and `privateKey` are PEM.
        private static func decode(_ bytes: Data) -> String {
            if let json = try? JSONSerialization.jsonObject(with: bytes),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: pretty, encoding: .utf8) {
                return string
            }

            if let string = String(data: bytes, encoding: .utf8), !string.isEmpty {
                return string
            }

            return bytes.base64EncodedString()
        }

        /// `SecurePersistentCache` appends a hash of the user ID to this.
        private static let servicePrefix = "ProTUN_"
    }

    extension DependencyValues {
        var proTUNKeychainClient: ProTUNKeychainClient {
            get { self[ProTUNKeychainClient.self] }
            set { self[ProTUNKeychainClient.self] = newValue }
        }
    }

    /// Contents of one `SecurePersistentCache` keychain service.
    package struct ProTUNCache: Equatable, Sendable, Identifiable {
        package let service: String
        package let entries: [Entry]

        package var id: String {
            service
        }

        package struct Entry: Equatable, Sendable, Identifiable {
            package let account: String
            package let byteCount: Int
            package let decodedValue: String

            package var id: String {
                account
            }
        }
    }
#endif
