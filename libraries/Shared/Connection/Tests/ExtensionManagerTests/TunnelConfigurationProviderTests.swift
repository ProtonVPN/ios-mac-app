//
//  Created on 06/03/2026 by Chris Janusiewicz.
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

    import XCTest

    import Dependencies

    @testable import ExtensionManager

    final class VPNManagerRepositoryTests: XCTestCase {
        func testCreatesAndLoadsManagerWithNoExistingManagers() async throws {
            let existingManagersLoaded = XCTestExpectation(description: "Tunnel Manager should check if a provider manager already exists")
            let newManagerLoaded = XCTestExpectation(description: "Tunnel Manager must load any newly created manager")

            let newManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .requiresSave)

            newManager.loadFromPreferencesBlock = { newManagerLoaded.fulfill() }
            try await withDependencies {
                $0.bundleIDClient = .mock(bundleID: "123")
                $0.tunnelProviderConfigurator = .init(configure: { _, _ in })
                $0.tunnelProviderManagerFactory = .init(
                    create: { _ in newManager },
                    removeAll: unimplemented(),
                    loadFromPreferences: {
                        existingManagersLoaded.fulfill()
                        return []
                    }
                )
            } operation: {
                let repository = VPNManagerRepositoryImplementation()
                _ = try await repository.prepareManager(of: .wireGuard(.go), for: .disconnection)
            }

            await fulfillment(of: [existingManagersLoaded, newManagerLoaded], timeout: 1)
        }

        func testLoadsManagerWithMatchingBundleIdentifier() async throws {
            let existingManagersLoaded = XCTestExpectation(description: "Tunnel Manager should check if a provider manager already exists")

            let existingManager = MockTunnelProviderManager(
                withBundleIdentifier: "123",
                state: .ready
            )

            _ = try await withDependencies {
                $0.bundleIDClient = .mock(bundleID: "123")
                $0.tunnelProviderManagerFactory = .init(
                    create: { _ in existingManager },
                    removeAll: unimplemented(),
                    loadFromPreferences: {
                        existingManagersLoaded.fulfill()
                        return [existingManager]
                    }
                )
            } operation: {
                let repository = VPNManagerRepositoryImplementation()
                _ = try await repository.managers()
            }

            await fulfillment(of: [existingManagersLoaded], timeout: 1)
        }
    }

#endif
