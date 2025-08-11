//
//  Created on 2025-07-28 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

#if canImport(AppKit)

    import Testing

    import Sharing

    @testable import VPNAppCore

    struct PlutoniumScannerTests {
        @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated
        @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
        @SharedReader(.childBundles) var childBundles: [String: ChildBundle]

        @Test
        func exclusionTriggersScanner() async throws {
            let scanner = await PlutoniumScanner(
                debounce: 0,
                scheduler: .immediate
            )

            #expect(childBundles.isEmpty)

            $exclusionActivated.apps.withLock {
                $0 = [.huzza]
            }
            #expect(childBundles.isEmpty)
            await scanner.waitForScanToComplete()
            #expect(!childBundles.isEmpty)
        }

        @Test
        func inclusionTriggersScanner() async throws {
            let scanner = await PlutoniumScanner(
                debounce: 0,
                scheduler: .immediate
            )

            #expect(childBundles.isEmpty)

            $inclusionActivated.withLock {
                $0.apps = [.huzza]
            }
            #expect(childBundles.isEmpty)
            await scanner.waitForScanToComplete()
            #expect(!childBundles.isEmpty)
        }
    }

#endif
