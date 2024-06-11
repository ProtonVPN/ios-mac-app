//
//  Created on 31/05/2024.
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

#if targetEnvironment(simulator)
import Foundation
import enum NetworkExtension.NEVPNStatus
import Dependencies
import XCTestDynamicOverlay
import ExtensionIPC
import let ConnectionFoundations.log

final class MockVPNConnection: VPNSession {
    package var connectedDate: Date?
    package var status: NEVPNStatus {
        didSet {
            NotificationCenter.default.post(name: Notification.Name.NEVPNStatusDidChange, object: self)
        }
    }

    var connectionTask: Task<Void, Error>?
    var disconnectionTask: Task<Void, Error>?
    var lastDisconnectError: Error?

    init(
        status: NEVPNStatus,
        connectedDate: Date? = nil,
        lastDisconnectError: Error? = nil
    ) {
        log.info("MockVPNConnection created")
        self.status = status
        self.connectedDate = connectedDate
        self.lastDisconnectError = lastDisconnectError
    }

    func fetchLastDisconnectError() async throws -> Error? { lastDisconnectError }

    func startTunnel() throws {
        self.status = .connecting
        connectionTask = Task {
            @Dependency(\.continuousClock) var clock
            try await clock.sleep(for: .seconds(1))

            @Dependency(\.date) var date
            connectedDate = date.now
            self.status = .connected
        }
    }

    func stopTunnel() {
        disconnectionTask = Task {
            @Dependency(\.continuousClock) var clock
            try await clock.sleep(for: .seconds(1))
            status = .disconnected
        }
    }

    // MARK: ProviderMessageSender conformance

    func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws {
        XCTFail("Unimplemented")
    }

    func send<R: ProviderRequest>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?)  {
        XCTFail("Unimplemented")
    }
}
#endif
