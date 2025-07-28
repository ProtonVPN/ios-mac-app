//
//  Created on 28/07/2025 by Max Kupetskyi.
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

import ComposableArchitecture
import Foundation
@testable import NATPMPUI
@testable import NATPortMapping
import Testing

@MainActor
struct NATPMPFeatureTests {
    @Test
    func startPortMappingReceiveAndStop() async {
        let mockService = NATPortMappingServiceMock()

        let store = TestStore(initialState: NATPMPFeature.State(isLoading: false)) {
            NATPMPFeature()
        } withDependencies: {
            $0.natPortMappingService = mockService
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1000) }
        }

        // Start port mapping
        await store.send(.startPortMapping) {
            $0.isLoading = true
        }

        // Send first port mapping response
        let firstResponse = createPortMappingResponse(externalPort: 8080)
        mockService.portMappingContinuation.yield(firstResponse)

        await store.receive(\.portMapped) {
            $0.isLoading = false
            $0.externalPortNumber = 8080
            $0.updateDate = Date(timeIntervalSince1970: 1000)
        }

        // Send second port mapping response with different port
        let secondResponse = createPortMappingResponse(externalPort: 9090)
        mockService.portMappingContinuation.yield(secondResponse)

        store.dependencies.date = DateGenerator { Date(timeIntervalSince1970: 2000) }

        await store.receive(\.portMapped) {
            $0.externalPortNumber = 9090
            $0.updateDate = Date(timeIntervalSince1970: 2000)
        }

        // Send third response with same port (should not update anything)
        let thirdResponse = createPortMappingResponse(externalPort: 9090)
        mockService.portMappingContinuation.yield(thirdResponse)

        await store.receive(\.portMapped)

        // Stop port mapping
        await store.send(.stopPortMapping)

        // Finish the stream
        mockService.portMappingContinuation.finish()
    }

    @Test
    func startPortMappingReceiveError() async {
        let mockService = NATPortMappingServiceMock()

        let store = TestStore(initialState: NATPMPFeature.State(isLoading: false)) {
            NATPMPFeature()
        } withDependencies: {
            $0.natPortMappingService = mockService
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1000) }
        }

        // Start port mapping
        await store.send(.startPortMapping) {
            $0.isLoading = true
        }

        // Send an error to the stream
        struct TestError: Error {}
        mockService.portMappingContinuation.finish(throwing: TestError())

        // Should receive portMappingFailed action
        await store.receive(\.portMappingFailed) {
            $0.isLoading = false
            $0.externalPortNumber = nil
            $0.updateDate = nil
        }
    }

    // MARK: - Helper functions

    private func createPortMappingResponse(externalPort: UInt16) -> PortMappingPacketResponse {
        // Create a packet response data array
        // version: 0, opcode: 129 (UDP response), result code: 0 (success)
        // epoch time: 1000 (matches test date)
        // internal port: 1234 (arbitrary)
        // external port: as specified
        // lifetime: 7200 (arbitrary)

        var data = Data()
        data.append(0) // version
        data.append(129) // opcode (UDP response)
        data.append(contentsOf: UInt16(0).bigEndian.bytes) // result code (success)
        data.append(contentsOf: UInt32(1000).bigEndian.bytes) // epoch time
        data.append(contentsOf: UInt16(1234).bigEndian.bytes) // internal port
        data.append(contentsOf: externalPort.bigEndian.bytes) // external port
        data.append(contentsOf: UInt32(7200).bigEndian.bytes) // lifetime

        do {
            return try PortMappingPacketResponse(from: data)
        } catch {
            fatalError("Failed to create test PortMappingPacketResponse: \(error)")
        }
    }
}
