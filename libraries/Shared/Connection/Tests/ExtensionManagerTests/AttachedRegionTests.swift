//
//  Created on 18/08/2026.
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

#if os(macOS)
    @testable import ExtensionSync
    import IPCDefinitions
    import IPCErgonomics
    import Testing

    /// `AttachedRegion.replace` decides whether a fresh store gets installed. Used on macOS with IOSurface.
    @Suite("Attached region")
    struct AttachedRegionTests {
        private func makeStore() throws -> ReaderStore {
            let surface = try #require(
                IOSurfaceBackedRegion.makeIOSurface(size: MemoryLayout<IPCTunnelData>.size)
            )
            return .attached(to: surface)
        }

        @Test("Installs into an empty region")
        func installsWhenEmpty() throws {
            let region = AttachedRegion()
            #expect(region.store == nil)
            #expect(region.regionID == nil)

            let installed = try region.replace(when: { $0 == nil }) { try makeStore() }
            #expect(installed)
            #expect(region.regionID != nil)
        }

        @Test("A staleness check that fails skips building the store")
        func freshCurrentSkipsMake() throws {
            let region = AttachedRegion()
            try region.replace(when: { $0 == nil }) { try makeStore() }

            var built = false
            region.replace(when: { _ in false }) {
                built = true
                return try! makeStore()
            }
            #expect(!built)
        }

        @Test("A genuine replacement changes the region identity")
        func replacementSwapsIdentity() throws {
            let region = AttachedRegion()
            try region.replace(when: { $0 == nil }) { try makeStore() }
            let first = try #require(region.regionID)

            let installed = try region.replace(when: { $0?.regionID == first }) { try makeStore() }
            #expect(installed)
            #expect(region.regionID != first)
        }

        @Test("A replacement that loses the install race installs nothing")
        func lostRaceInstallsNothing() throws {
            let region = AttachedRegion()
            try region.replace(when: { $0 == nil }) { try makeStore() }
            let resident = try #require(region.regionID)

            // Stale on the first check, no longer stale at install: what a concurrent replace would produce.
            var checks = 0
            let installed = try region.replace(when: { _ in
                checks += 1
                return checks == 1
            }) {
                try makeStore()
            }
            #expect(!installed)
            #expect(checks == 2)
            #expect(region.regionID == resident)
        }
    }
#endif
