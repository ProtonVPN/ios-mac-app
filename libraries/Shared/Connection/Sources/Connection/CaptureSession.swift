//
//  Created on 11/08/2026.
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

import CasePaths
import Dependencies
import Domain
import ExtensionSync
import Foundation
import Sharing

/// The extension's capture report paired with the capture file on disk.
@CasePathable
public enum CaptureSession: Equatable, Sendable {
    case noSession
    case sessionPending(urlWithDate: URLWithDate)
    case sessionStarted(urlWithDate: URLWithDate)
    case sessionEnded(urlWithSize: URLWithSize)

    public var isRunning: Bool {
        self.is(\.sessionStarted) || self.is(\.sessionPending)
    }
}

public extension SharedReaderKey where Self == StreamReaderKey<CaptureSession> {
    static var captureSession: Self {
        StreamReaderKey(
            read: {
                @Dependency(\.packetCaptureClient) var packetCaptureClient
                return packetCaptureClient.session()
            },
            updates: {
                @Dependency(\.packetCaptureClient) var packetCaptureClient
                return packetCaptureClient.observeSession()
            }
        )
    }
}
