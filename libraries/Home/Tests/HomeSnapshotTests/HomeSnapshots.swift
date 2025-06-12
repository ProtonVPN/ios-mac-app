//
//  Created on 07/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

#if compiler(>=6) && canImport(Testing)

    import ComposableArchitecture
    import Domain
    import DomainTestSupport
    import Ergonomics
    @testable import Home
    @testable import HomeShared
    import IssueReporting
    import OrderedCollections
    import SnapshotTesting
    import SwiftUI
    import Testing
    import VPNAppCore

    @Suite("Home")
    struct SwiftTestingTests {
        static let homeTestData = [
            (
                ProtectionState.unprotected,
                VPNConnectionStatus.disconnected
            ),
            (
                ProtectionState.protecting(country: "Poland", ip: "1.2.3.4"),
                VPNConnectionStatus.connecting(.specificCountryServer, .mock(
                    country: "PL",
                    coordinates: .init(latitude: 52.229686, longitude: 21.012247)
                ))
            ),
            (
                ProtectionState.protected(netShield: .init(trackersCount: 432, adsCount: 12345, dataSaved: 123_456_789, enabled: true)),
                VPNConnectionStatus.connected(.specificCountryServer, .mock(
                    country: "PL",
                    coordinates: .init(latitude: 52.229686, longitude: 21.012247)
                ))
            ),
        ]

        @Shared(.protectionState) var protectionState
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus
        @Shared(.userTier) var userTier
        @Shared(.userCountry) var userCountry
        @Shared(.userIP) var userIP
        @Shared(.recents) var recents
        @Shared(.netShieldLevel) var netShieldLevel

        @Test("Home screen", arguments: [Int.freeTier, Int.paidTier], homeTestData)
        @MainActor
        func homeScreen(tier: Int, state: (protection: ProtectionState, connection: VPNConnectionStatus)) async throws {
            let store = Store(initialState: HomeFeature.State(), reducer: HomeFeature.init) {
                $0.serverChangeAuthorizer = .availableValue
                $0.locale = .en
                $0.date = .constant(Date())
            }
            let appView = HomeView(store: store)
                .frame(.rect(width: 375, height: 667)) // iphone se 2022 size
                .environment(\._accessibilityReduceMotion, true)
                .environment(\.colorScheme, .dark)

            withDependencies {
                $0.locale = .en
                $0.date = .constant(Date())
            } operation: {
                $netShieldLevel |=| .level2
                $recents |=| [.connectionRegion, .connectionSecureCoreFastest, .connectionSecureCore]
                $userCountry |=| "PL"
                $userIP |=| "1.2.3.4"
                $userTier |=| tier
                $protectionState |=| state.protection
                $vpnConnectionStatus |=| state.connection

                let testName = [tier.isFreeTier ? "Free" : "Paid",
                                protectionState.shortDescription(),
                                vpnConnectionStatus.shortDescription()].joined(separator: "-")

                assertSnapshot(of: appView, as: .image, testName: testName)
            }
        }

        private func assertSnapshot<Value>(
            of value: @autoclosure () throws -> Value,
            as snapshotting: Snapshotting<Value, some Any>,
            named name: String? = nil,
            record recording: Bool? = nil,
            timeout: TimeInterval = 5,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            var snapshotDirectory: String?
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
                snapshotDirectory = "\(projectDir)/libraries/Home/Tests/HomeSnapshotTests/__Snapshots__/HomeSnapshots"
            }

            let failure = try verifySnapshot(
                of: value(),
                as: snapshotting,
                named: name,
                record: recording,
                snapshotDirectory: snapshotDirectory,
                timeout: timeout,
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
            guard let message = failure else { return }
            reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
        }
    }

    infix operator |=|

    public func |=| <Value>(lhs: Shared<Value>, rhs: Value) {
        lhs.withLock { $0 = rhs }
    }

    extension Locale {
        static let en = Locale(identifier: "en")
    }

    extension ProtectionState {
        fileprivate func shortDescription() -> String {
            switch self {
            case .unprotected: "Unprotected"
            case .protecting: "Protecting"
            case .protected: "Protected"
            case .protectedSecureCore: "ProtectedSecureCore"
            case .resolving: "Loading"
            }
        }
    }

    extension VPNConnectionStatus {
        fileprivate func shortDescription() -> String {
            switch self {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting"
            case .resolving: "Loading"
            case .disconnecting: "Disconnecting"
            case .connected: "Connected"
            }
        }
    }

#endif

/*
 We should only have a few tests on the whole home page, it's not meant to be comprehensive, just to make sure the elements fit together
 Home screen: both dark and light (12), all centered on a different country
 - free user; unprotected; ; upsells
 - free user; unprotected; upsells visible first
 - free user; protected; upsells visible last
 - paid user; protected; with recents
 - paid user; unprotected; with recents scrolled to bottom

 Map: only the map with pin, without the other elements, every using different country, both dark and light (12)
 - whole map without pin, without country
 - country with pin unprotected
 - country with pin protecting
 - country with pin protected
 - biggest country with pin protected
 - smallest country with pin protected

 Connection status: both dark and light (12)
 - unprotected, without location info
 - unprotected, with location info
 - protected free user with netshield banner
 - protected free user with change server banner
 - protected paid user with netshield
 - protected paid user without netshield

 Connection card: (16) both dark and light
 - free user, fastest country disconnected
 - free user, fastest country connected
 - paid user, fastest country secure core
 - paid user, specific country, connected
 - paid user, specific country, disconnected, secure core
 - paid user, specific country and city disconnected
 - paid user, specific country, city and server connected
 - paid user, specific country and server disconnected

 Recents:
 - under maintenance
 - secure core
 - more

 */
