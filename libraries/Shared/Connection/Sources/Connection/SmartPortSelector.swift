//
//  Created on 23/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Domain

import Dependencies

public struct ServerEndpointPortResolution: Sendable {
    public let chosenProtocol: VpnProtocol
    public let ports: [Int]

    public init(chosenProtocol: VpnProtocol, ports: [Int]) {
        self.chosenProtocol = chosenProtocol
        self.ports = ports
    }
}

public struct SmartPortSelectorBridge: Sendable {
    public typealias SelectHandler = @Sendable (
        _ endpoint: ServerEndpoint,
        _ connectionProtocol: ConnectionProtocol
    ) async throws -> ServerEndpointPortResolution

    public internal(set) var select: SelectHandler

    public init(select: @escaping SelectHandler) {
        self.select = select
    }
}

extension SmartPortSelectorBridge: TestDependencyKey {
    public static let testValue: SmartPortSelectorBridge = .init(
        select: unimplemented(placeholder: .init(chosenProtocol: .wireGuard(.udp), ports: [0]))
    )
}

extension DependencyValues {
    public var smartPortSelector: SmartPortSelectorBridge {
        get { self[SmartPortSelectorBridge.self] }
        set { self[SmartPortSelectorBridge.self] = newValue }
    }
}
