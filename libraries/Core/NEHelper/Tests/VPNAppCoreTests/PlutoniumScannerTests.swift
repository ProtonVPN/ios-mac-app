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

    import ConcurrencyExtras
    import Sharing
    import Testing
    @testable import VPNAppCore

    // Serialized because every test mutates the same file-backed `@Shared` state
    // (`exclusionActivated`/`inclusionActivated`/`childBundles`) and each scanner
    // observes *both* lists, so parallel tests would cross-trigger each other.
    @Suite(.serialized)
    struct PlutoniumScannerTests {
        @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated
        @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
        @Shared(.childBundles) var childBundles: [String: ChildBundle]

        /// Clears the shared state that persists on disk between tests and runs.
        private func resetSharedState() {
            $exclusionActivated.withLock { $0 = .init() }
            $inclusionActivated.withLock { $0 = .init() }
            $childBundles.withLock { $0 = [:] }
        }

        @Test
        func exclusionTriggersScanner() async {
            // `withMainSerialExecutor` pins the observation pipeline to a single
            // executor so the scan the change triggers runs before we assert.
            await withMainSerialExecutor {
                resetSharedState()

                let scanner = PlutoniumScanner(
                    debounce: 0,
                    scheduler: .immediate
                )
                await scanner.startObservation()

                #expect(childBundles.isEmpty)

                $exclusionActivated.apps.withLock {
                    $0 = [.huzza]
                }
                await scanner.waitForScanToComplete()
                #expect(!childBundles.isEmpty)
            }
        }

        @Test
        func inclusionTriggersScanner() async {
            await withMainSerialExecutor {
                resetSharedState()

                let scanner = PlutoniumScanner(
                    debounce: 0,
                    scheduler: .immediate
                )
                await scanner.startObservation()

                #expect(childBundles.isEmpty)

                $inclusionActivated.withLock {
                    $0.apps = [.huzza]
                }
                await scanner.waitForScanToComplete()
                #expect(!childBundles.isEmpty)
            }
        }
    }

#endif
