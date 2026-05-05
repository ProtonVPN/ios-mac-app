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

import Dependencies
import enum ExtensionIPC.ProviderMessageError
import enum ExtensionIPC.WireguardProviderRequest

#if DEBUG && os(iOS)
    import enum Domain.ProTUNMessage
#endif

public struct TunnelMessageSender: TestDependencyKey {
    public var send: (WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response
    #if DEBUG && os(iOS)
        public var sendProTUN: (ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response
    #endif

    #if DEBUG && os(iOS)
        public init(
            send: @escaping (WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response,
            sendProTUN: @escaping (ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response
        ) {
            self.send = send
            self.sendProTUN = sendProTUN
        }

        public static let testValue = TunnelMessageSender(
            send: unimplemented(throwing: .noDataReceived),
            sendProTUN: unimplemented(throwing: .noDataReceived)
        )
    #else
        public init(
            send: @escaping (WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response
        ) {
            self.send = send
        }

        public static let testValue = TunnelMessageSender(
            send: unimplemented(throwing: .noDataReceived)
        )
    #endif
}

public extension DependencyValues {
    var tunnelMessageSender: TunnelMessageSender {
        get { self[TunnelMessageSender.self] }
        set { self[TunnelMessageSender.self] = newValue }
    }
}
