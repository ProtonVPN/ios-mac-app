//
//  Created on 2026-06-26 by Pawel Jurczyk.
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

import ComposableArchitecture
import Connection
import Domain
import Foundation
@testable import PCAPShared
import Testing

@Suite("Capture VPN Session Feature Tests", .serialized)
@MainActor
struct CaptureVPNSessionFeatureTests {
    @Test
    func `low storage alert`() async {
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        } withDependencies: {
            $0.volumeAvailableCapacity = .value(with: CaptureVPNSessionFeature.minimumStorageCapacity - 1)
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity) {
            $0.storageCapacity = CaptureVPNSessionFeature.minimumStorageCapacity - 1
        }
        await store.receive(\.captureSessionUpdate.noSession)
        await store.send(.captureButtonPressed) {
            $0.alert = CaptureVPNSessionFeature.lowStorageAlert
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.send(.onDisappear)
    }

    @Test
    func `start capturing alert`() async {
        var onTogglePacketCaptureCalled = false
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        } withDependencies: {
            $0.volumeAvailableCapacity = .value(with: CaptureVPNSessionFeature.minimumStorageCapacity)
            $0.packetCaptureClient = .stub(onTogglePacketCapture: {
                onTogglePacketCaptureCalled = true
            })
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity) {
            $0.storageCapacity = CaptureVPNSessionFeature.minimumStorageCapacity
        }
        await store.receive(\.captureSessionUpdate.noSession)

        await store.send(.captureButtonPressed) {
            $0.alert = CaptureVPNSessionFeature.startCapturingAlert
        }
        await store.send(.alert(.presented(.startCapturing))) {
            $0.alert = nil
        }
        await store.receive(\.togglePacketCapture)
        #expect(onTogglePacketCaptureCalled)
        await store.send(.onDisappear)
    }

    @Test
    func `start capturing error`() async {
        var onTogglePacketCaptureCalled = false
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        } withDependencies: {
            $0.volumeAvailableCapacity = .value(with: CaptureVPNSessionFeature.minimumStorageCapacity)
            $0.packetCaptureClient = .stub(onTogglePacketCapture: {
                onTogglePacketCaptureCalled = true
                throw PacketCaptureClientError.failedToStart(PCAPTestError.testError)
            })
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity) {
            $0.storageCapacity = CaptureVPNSessionFeature.minimumStorageCapacity
        }
        await store.receive(\.captureSessionUpdate.noSession)

        await store.send(.captureButtonPressed) {
            $0.alert = CaptureVPNSessionFeature.startCapturingAlert
        }
        await store.send(.alert(.presented(.startCapturing))) {
            $0.alert = nil
        }
        await store.receive(\.togglePacketCapture)
        await store.receive(\.showErrorMessage) {
            $0.alert = CaptureVPNSessionFeature.sessionCaptureFailedAlert(message: "The operation couldn’t be completed. (Connection.PacketCaptureClientError error 0.)")
        }
        #expect(onTogglePacketCaptureCalled)
        await store.send(.onDisappear)
    }

    @Test
    func `stop capturing`() async {
        @Shared(.captureSession) var captureSession
        $captureSession.withLock {
            $0 = .sessionStarted(urlWithDate: URLWithDate(url: URL(filePath: "file.pcap"), date: .now))
        }
        var onTogglePacketCaptureCalled = false
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        } withDependencies: {
            $0.volumeAvailableCapacity = .value(with: CaptureVPNSessionFeature.minimumStorageCapacity)
            $0.packetCaptureClient = .stub(onTogglePacketCapture: {
                onTogglePacketCaptureCalled = true
            })
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity) {
            $0.storageCapacity = CaptureVPNSessionFeature.minimumStorageCapacity
        }
        await store.receive(\.captureSessionUpdate.sessionStarted)

        await store.send(.captureButtonPressed)
        await store.receive(\.togglePacketCapture)
        #expect(onTogglePacketCaptureCalled)
        await store.send(.onDisappear)
    }

    @Test
    func `session ended presents session captured sheet`() async {
        @Shared(.captureSession) var captureSession
        $captureSession.withLock {
            $0 = .sessionEnded(
                urlWithSize: URLWithSize(url: URL(filePath: "file.pcap"), size: 123),
                reason: .explicitStop
            )
        }
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity) {
            $0.storageCapacity = 100
        }
        await store.receive(\.captureSessionUpdate.sessionEnded) {
            $0.destination = .sessionCaptured(.init())
        }
        await store.send(.onDisappear)
    }

    @Test
    func `cant read volumeAvailableCapacity allows capture`() async {
        var onTogglePacketCaptureCalled = false
        let store = TestStore(initialState: CaptureVPNSessionFeature.State()) {
            CaptureVPNSessionFeature()
        } withDependencies: {
            $0.volumeAvailableCapacity = .throwing(error: .failedRetrievingAvailableCapacity)
            $0.packetCaptureClient = .stub(onTogglePacketCapture: {
                onTogglePacketCaptureCalled = true
            })
        }
        await store.send(.onAppear)
        await store.receive(\.refreshStorageCapacity)
        await store.receive(\.captureSessionUpdate.noSession)

        await store.send(.captureButtonPressed) {
            $0.alert = CaptureVPNSessionFeature.startCapturingAlert
        }
        await store.send(.alert(.presented(.startCapturing))) {
            $0.alert = nil
        }
        await store.receive(\.togglePacketCapture)
        #expect(onTogglePacketCaptureCalled)
        await store.send(.onDisappear)
    }
}

enum PCAPTestError: Error, CustomStringConvertible {
    var description: String {
        "just a test error"
    }

    case testError
}
