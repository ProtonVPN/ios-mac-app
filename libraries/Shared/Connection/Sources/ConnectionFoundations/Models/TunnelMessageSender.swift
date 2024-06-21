//
//  Created on 14/06/2024.
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

import Foundation
import Dependencies

import enum ExtensionIPC.WireguardProviderRequest
import enum ExtensionIPC.ProviderMessageError

public struct TunnelMessageSender: TestDependencyKey {
    public var send: (WireguardProviderRequest) async throws -> WireguardProviderRequest.Response

    public init(
        send: @escaping (WireguardProviderRequest) async throws -> WireguardProviderRequest.Response
    ) {
        self.send = send
    }

    public static let testValue = TunnelMessageSender(send: unimplemented())
}

extension DependencyValues {
    public var tunnelMessageSender: TunnelMessageSender {
        get { self[TunnelMessageSender.self] }
        set { self[TunnelMessageSender.self] = newValue }
    }
}
