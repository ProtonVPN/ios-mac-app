//
//  Created on 28/11/2024.
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

@preconcurrency import VPNAppCore

import Dependencies
import DependenciesMacros

@DependencyClient
@available(iOS 16, *)
public struct ConnectionBridge: Sendable {
    // For prototyping, let's just typealias.
    // Later we can define an enum with a concrete set of actions like connect(...) and disconnect
    public typealias Intent = ConnectionFeature.Action

    // When Swift6 available, switch to some AsyncSequence<ConnectionIntent, Never> or equivalent
    public internal(set) var intentStream: AsyncStream<Intent>

    // When Swift6 available, switch to some AsyncSequence<VPNConnectionStatus, Never> or equivalent
    public internal(set) var statusStream: AsyncStream<VPNConnectionStatus>

    public internal(set) var push: @Sendable (_ intent: Intent) -> Void
    public internal(set) var pushStatus: @Sendable (_ status: VPNConnectionStatus) -> Void
}

extension DependencyValues {
    public var connectionBridge: ConnectionBridge {
        get { self[ConnectionBridge.self] }
        set { self[ConnectionBridge.self] = newValue }
    }
}

extension ConnectionBridge: DependencyKey {
    public static let liveValue = {
        let (intentStream, intentContinuation) = AsyncStream<Intent>.makeStream()
        let (statusStream, statusContinuation) = AsyncStream<VPNConnectionStatus>.makeStream()
        // We have to feed the statusStream continuation an initial value
        // TODO: Make the initial value reflective off the real current state
        statusContinuation.yield(.disconnected)
        return ConnectionBridge(intentStream: intentStream, statusStream: statusStream) { intent in
            intentContinuation.yield(intent)
        } pushStatus: { status in
            statusContinuation.yield(status)
        }
    }()

    public static let testValue: ConnectionBridge = liveValue
}
