//
//  Created on 06/05/2026 by Max Kupetskyi.
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
    import ComposableArchitecture
    @testable import Settings_iOS
    @testable import SettingsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct KeychainDebugViewSnapshotTests {
        private let expandedSize = CGSize(width: 430, height: 1100)

        @Test("KeychainDebugView")
        func keychainDebugView() {
            let store = Store(
                initialState: KeychainDebugFeature.State(
                    alert: nil,
                    content: .failed("Failed to load keychain data")
                ),
                reducer: { KeychainDebugFeature() }
            )

            let view = NavigationStack {
                KeychainDebugView(store: .constant(store))
            }
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("KeychainDebugView with loaded keychain data")
        func keychainDebugViewLoaded() {
            let store = Store(
                initialState: KeychainDebugFeature.State(
                    alert: nil,
                    content: .loaded(.sample)
                ),
                reducer: { KeychainDebugFeature() }
            )

            let view = NavigationStack {
                KeychainDebugView(store: .constant(store))
            }
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .fixed(width: expandedSize.width, height: expandedSize.height)))
        }
    }

    private extension KeychainDebugFeature.KeychainData {
        static let sample = Self(
            authKeychainData: .sample,
            unauthKeychainData: nil,
            proTUNCaches: [
                ProTUNCache(
                    service: "ProTUN_x1x9hSjRk0eIcm5DcxZ0Jw==",
                    entries: [
                        .init(account: "apiSession", byteCount: 512, decodedValue: "{\n  \"Internal\" : { }\n}"),
                        .init(account: "certificate", byteCount: 1024, decodedValue: "-----BEGIN CERTIFICATE-----"),
                        .init(account: "privateKey", byteCount: 128, decodedValue: "-----BEGIN PRIVATE KEY-----"),
                    ]
                ),
            ]
        )
    }

    private extension KeychainDebugFeature.AuthKeychainData {
        static let sample = Self(
            username: "vpn_user",
            accessToken: "5up3r53cr3t4cc3ss70k3n",
            refreshToken: "5up3r53cr3tr3fr35h70k3n",
            sessionId: "5e5510n1d",
            userId: "u53r1d",
            scopes: ["self", "vpn"]
        )
    }

    extension KeychainDebugViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Settings/Tests/SettingsTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
