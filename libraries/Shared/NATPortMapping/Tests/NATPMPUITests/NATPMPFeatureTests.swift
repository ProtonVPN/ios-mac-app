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

        let store = TestStore(initialState: NATPMPFeature.State.loading(lastExternalPortNumber: nil, lastUsedUpdateDate: nil)) {
            NATPMPFeature()
        } withDependencies: {
            $0.natPortMappingService = mockService
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1000) }
        }

        // Start port mapping observation
        await store.send(.startPortMappingObservation)

        // Send first port mapping response
        let firstResponseDate = Date(timeIntervalSince1970: 999)
        let firstResponse = createPortMappingResponse(externalPort: 8080, createDate: firstResponseDate)
        mockService.portMappingStream.value = .success(firstResponse)

        // observation started before first response; current value subject holds `nil`
        await store.receive(\.portMappingReceivedNil)

        await store.receive(\.portMapped) {
            $0 = .loaded(externalPortNumber: 8080, updateDate: firstResponseDate)
        }

        store.dependencies.date = DateGenerator { Date(timeIntervalSince1970: 2000) }

        // Send second port mapping response with different port
        let secondResponseDate = Date(timeIntervalSince1970: 1999)
        let secondResponse = createPortMappingResponse(externalPort: 9090, createDate: secondResponseDate)
        mockService.portMappingStream.value = .success(secondResponse)

        await store.receive(\.portMapped) {
            $0 = .loaded(externalPortNumber: 9090, updateDate: secondResponseDate)
        }

        store.dependencies.date = DateGenerator { Date(timeIntervalSince1970: 3000) }

        // Send third response with same port
        let thirdResponseDate = Date(timeIntervalSince1970: 2999)
        let thirdResponse = createPortMappingResponse(externalPort: 9090, createDate: thirdResponseDate)
        mockService.portMappingStream.value = .success(thirdResponse)

        // no actions received since we filter duplicated mapping responses by port number

        // Stop port mapping observation
        await store.send(.stopPortMappingObservation)

        // send fourth response; no active subscription
        let fourthResponseCreateDate = Date()
        let fourthResponse = createPortMappingResponse(externalPort: 6666, createDate: fourthResponseCreateDate)
        store.dependencies.date = DateGenerator { fourthResponseCreateDate.addingTimeInterval(161) }

        mockService.portMappingStream.value = .success(fourthResponse)

        // Restart port mapping observation
        await store.send(.startPortMappingObservation) {
            // loading state holds previously used data
            $0 = .loading(lastExternalPortNumber: 9090, lastUsedUpdateDate: secondResponseDate)
        }

        // nothing happens because mapping has expired: now is fourthResponseCreateDate + 161, lifetime is 60
        await store.receive(\.portMapped)

        // Stop port mapping observation
        await store.send(.stopPortMappingObservation)

        // send fifth response; no active subscription
        let fifthResponseCreateDate = Date()
        let fifthResponse = createPortMappingResponse(externalPort: 7777, createDate: fifthResponseCreateDate)
        let nowDate = fifthResponseCreateDate.addingTimeInterval(5)
        store.dependencies.date = DateGenerator { nowDate }

        mockService.portMappingStream.value = .success(fifthResponse)

        // Restart port mapping observation
        await store.send(.startPortMappingObservation)

        // still valid mapping from before there was no observation
        await store.receive(\.portMapped) {
            $0 = .loaded(externalPortNumber: 7777, updateDate: fifthResponseCreateDate)
        }

        // Stop port mapping observation
        await store.send(.stopPortMappingObservation)

        // Finish the stream
        mockService.portMappingStream.send(completion: .finished)
    }

    @Test
    func startPortMappingReceiveError() async {
        let mockService = NATPortMappingServiceMock()

        let store = TestStore(
            initialState: NATPMPFeature.State.loading(lastExternalPortNumber: nil, lastUsedUpdateDate: nil)
        ) {
            NATPMPFeature()
        } withDependencies: {
            $0.natPortMappingService = mockService
            $0.date = DateGenerator { Date(timeIntervalSince1970: 1000) }
        }

        // Start port mapping
        await store.send(.startPortMappingObservation)

        await store.receive(\.portMappingReceivedNil)

        // Send an error to the stream
        struct TestError: Error {}
        mockService.portMappingStream.send(.failure(TestError()))

        // Should receive portMappingFailed action
        await store.receive(\.portMappingFailed) {
            $0 = .error
        }

        // Finish the stream
        mockService.portMappingStream.send(completion: .finished)
    }

    // MARK: - Helper functions

    private func createPortMappingResponse(externalPort: UInt16, createDate: Date) -> PortMappingPacketResponse {
        PortMappingPacketResponse(
            version: 0,
            opcode: 129, // UDP response
            resultCode: 0, // success
            epochTime: 1000,
            internalPort: 1234,
            mappedExternalPort: externalPort,
            mappingLifetime: 60,
            createDate: createDate
        )
    }
}
