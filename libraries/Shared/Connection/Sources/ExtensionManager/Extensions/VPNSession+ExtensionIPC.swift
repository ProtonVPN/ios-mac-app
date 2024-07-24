//
//  Created on 04/06/2024.
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
import NetworkExtension
import Dependencies
import protocol ExtensionIPC.ProviderRequest
import enum ExtensionIPC.ProviderMessageError
import ConnectionFoundations

@available(iOS 16, *)
extension TunnelMessageSender: DependencyKey {
    public static let liveValue: TunnelMessageSender = {
        @Dependency(\.tunnelManager) var tunnelManager
        return TunnelMessageSender(
            send: { message in
                try await tunnelManager.session.send(message)
            }
        )
    }()
}
