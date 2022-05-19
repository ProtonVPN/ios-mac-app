//
//  Created on 2022-04-21.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import NetworkExtension
import XCTest

struct MockDataTaskFactory: DataTaskFactory {
    typealias RequestCallback = (DataTaskProtocol, URLRequest, @escaping MockDataTask.CompletionCallback) -> Void
    let requestCallback: RequestCallback

    func dataTask(_ request: URLRequest, completionHandler: @escaping MockDataTask.CompletionCallback) -> DataTaskProtocol {
        return MockDataTask(request: request, dataTaskFactory: self, completionHandler: completionHandler)
    }
}

struct MockDataTask: DataTaskProtocol {
    typealias CompletionCallback = ((Data?, HTTPURLResponse?, Error?) -> Void)

    let request: URLRequest
    let dataTaskFactory: MockDataTaskFactory
    let completionHandler: CompletionCallback

    func resume() {
        dataTaskFactory.requestCallback(self, request, completionHandler)
    }
}

protocol MockConnectionWriteDelegate {

}

class MockConnectionTunnel: ConnectionTunnel & ObservationHandle {
    let hostname: String
    let port: String
    let usingTLS: Bool

    weak var factory: MockConnectionTunnelFactory!

    init(factory: MockConnectionTunnelFactory, hostname: String, port: String, usingTLS: Bool) {
        self.factory = factory
        self.hostname = hostname
        self.port = port
        self.usingTLS = usingTLS
    }

    var state: NWTCPConnectionState = .invalid {
        didSet {
            DispatchQueue.main.async {
                self.stateChangeCallback?(self.state)
            }
        }
    }

    var observationInvalidated = false {
        didSet {
            guard observationInvalidated else { return }
            stateChangeCallback = nil
        }
    }

    var closedForWriting = false

    var stateChangeCallback: ((NWTCPConnectionState) -> ())?

    func write(_ data: Data, completionHandler: @escaping (Error?) -> Void) {
        guard !closedForWriting else {
            XCTFail("Attempted to write after closing socket")
            return
        }

        guard state == .connected else {
            XCTFail("Attempted to write to socket that wasn't connected")
            return
        }

        do {
            guard let dataWriteCallback = factory?.dataWriteCallback else {
                XCTFail("No dataWriteCallback was set")
                return
            }

            try dataWriteCallback(self, data)
        } catch {
            completionHandler(error)
            return
        }

        completionHandler(nil)
    }

    func readMinimumLength(_ minimumLength: Int, maximumLength: Int, completionHandler: @escaping (Data?, Error?) -> Void) {
        guard state == .connected else {
            XCTFail("Attempted to read from socket that wasn't connected")
            return
        }


        let dataToRead: Data
        do {
            guard let dataReadCallback = factory?.dataReadCallback else {
                XCTFail("No dataReadCallback was set")
                return
            }

            dataToRead = try dataReadCallback(self)
            XCTAssertLessThan(minimumLength, dataToRead.count, "Data present is not sufficient for minimum length of socket read")
            XCTAssertLessThan(dataToRead.count, maximumLength, "Data present is greater than maximum specified in \(#function)")
        } catch {
            completionHandler(nil, error)
            return
        }

        completionHandler(dataToRead, nil)
    }

    func writeClose() {
        closedForWriting = true
    }

    func observeStateChange(withCallback callback: @escaping ((NWTCPConnectionState) -> ())) -> ObservationHandle {
        stateChangeCallback = callback
        factory?.stateObservingCallback(self)
        return self
    }

    func invalidate() {
        observationInvalidated = true
    }
}

class MockConnectionTunnelFactory: ConnectionTunnelFactory {
    typealias StateObservingCallback = ((MockConnectionTunnel) -> ())
    typealias DataReadCallback = ((MockConnectionTunnel) throws -> (Data))
    typealias DataWriteCallback = ((MockConnectionTunnel, Data) throws -> (Void))

    let stateObservingCallback: StateObservingCallback
    let dataReadCallback: DataReadCallback
    let dataWriteCallback: DataWriteCallback

    init(stateObservingCallback: @escaping StateObservingCallback,
         dataReadCallback: @escaping DataReadCallback,
         dataWriteCallback: @escaping DataWriteCallback)
    {
        self.stateObservingCallback = stateObservingCallback
        self.dataReadCallback = dataReadCallback
        self.dataWriteCallback = dataWriteCallback
    }

    var connections: [MockConnectionTunnel] = []

    func createTunnel(hostname: String, port: String, useTLS: Bool) -> ConnectionTunnel {
        let connection = MockConnectionTunnel(factory: self, hostname: hostname, port: port, usingTLS: useTLS)
        connections.append(connection)
        return connection
    }
}
