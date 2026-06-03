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
import enum Domain.ProTUNMessage
import enum ExtensionIPC.ProviderMessageError

public struct TunnelMessageSender: TestDependencyKey {
    public internal(set) var sendProTUN: (ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response

    public init(
        sendProTUN: @escaping (ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response
    ) {
        self.sendProTUN = sendProTUN
    }

    public static let testValue = TunnelMessageSender(
        sendProTUN: unimplemented(throwing: .noDataReceived)
    )
}

public extension DependencyValues {
    var tunnelMessageSender: TunnelMessageSender {
        get { self[TunnelMessageSender.self] }
        set { self[TunnelMessageSender.self] = newValue }
    }
}
