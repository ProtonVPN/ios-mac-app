//
//  Created on 23/02/2026.
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
    import Testing

    @testable import Domain

    @Suite("IPCCoder")
    struct IPCCoderTests {
        private let live = IPCCoder<ProTUNMessage.Request, ProTUNMessage.Response>.liveValue

        @Test("Request ping Encoding/Decoding assertions")
        func pingRoundTrip() throws {
            let original = ProTUNMessage.Request(payload: .ping)
            let data = try live.requestData(for: original)
            let decoded = try live.request(from: data)

            #expect(decoded.version == original.version)
            #expect(decoded.payload == original.payload)
        }

        @Test("Request getCurrentPeerID Encoding/Decoding assertions")
        func getCurrentPeerIDRequestRoundTrip() throws {
            let original = ProTUNMessage.Request(payload: .getCurrentPeerID)
            let data = try live.requestData(for: original)
            let decoded = try live.request(from: data)

            #expect(decoded.version == original.version)
            #expect(decoded.payload == original.payload)
        }

        @Test("Response pong Encoding/Decoding assertions")
        func pongRoundTrip() throws {
            let original = ProTUNMessage.Response(payload: .pong)
            let data = try live.responseData(for: original)
            let decoded = try live.handleResponse(from: data)

            #expect(decoded.version == original.version)
            #expect(decoded.payload == original.payload)
        }

        @Test("Response getCurrentPeerID Encoding/Decoding assertions for various cases")
        func currentPeerIDCasesRoundTrip() throws {
            let success = ProTUNMessage.Response(payload: .currentPeerID(.success("proton-peer-abc123")))
            let successData = try live.responseData(for: success)
            let successDecoded = try live.handleResponse(from: successData)

            #expect(successDecoded.version == success.version)
            #expect(successDecoded.payload == success.payload)

            let failure = ProTUNMessage.Response(payload: .currentPeerID(.failure(.init(failureReason: "State not connected"))))
            let failureData = try live.responseData(for: failure)
            let failureDecoded = try live.handleResponse(from: failureData)

            #expect(failureDecoded.version == success.version)
            #expect(failureDecoded.payload == failureDecoded.payload)
        }

        @Test("Other error responses preserves reason string")
        func errorOtherRoundTrip() throws {
            let original = ProTUNMessage.Response(payload: .error(.other(reason: "internal error")))
            let data = try live.responseData(for: original)
            let decoded = try live.handleResponse(from: data)

            #expect(decoded.payload == original.payload)
        }

        @Test("Invalid request data encoding throws error")
        func decodingGarbageRequestThrows() {
            let garbage = Data(repeating: 0xFF, count: 32)
            #expect(throws: (any Error).self) {
                try live.request(from: garbage)
            }
        }

        @Test("Invalid response data encoding throws error")
        func decodingGarbageResponseThrows() {
            let garbage = Data(repeating: 0xFF, count: 32)
            #expect(throws: (any Error).self) {
                try live.handleResponse(from: garbage)
            }
        }

        @Test("Empty request data encoding throws error ")
        func decodingEmptyDataRequestThrows() {
            #expect(throws: (any Error).self) {
                try live.request(from: Data())
            }
        }

        @Test("response data cannot be decoded as a Request")
        func responseBytesDecodedAsRequestThrows() throws {
            // The payload enum cases differ between Request and Response, so
            // valid response data should fail when decoded as a Request.
            let responseData = try live.responseData(for: .init(payload: .pong))
            #expect(throws: (any Error).self) {
                try live.request(from: responseData)
            }
        }

        @Test("encoding always produces non-empty binary data")
        func encodingProducesNonEmptyData() throws {
            let requestBytes = try live.requestData(for: .init(payload: .ping))
            #expect(!requestBytes.isEmpty)

            let getCurrentPeerIDBytes = try live.requestData(for: .init(payload: .getCurrentPeerID))
            #expect(!getCurrentPeerIDBytes.isEmpty)

            let pongBytes = try live.responseData(for: .init(payload: .pong))
            #expect(!pongBytes.isEmpty)

            let currentPeerIDBytes = try live.responseData(for: .init(payload: .currentPeerID(.success("Proton"))))
            #expect(!currentPeerIDBytes.isEmpty)

            let errorBytes = try live.responseData(for: .init(payload: .error(.other(reason: "oops"))))
            #expect(!errorBytes.isEmpty)
        }
    }
#endif
