//
//  Created on 2023-06-16.
//
//  Copyright (c) 2023 Proton AG
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
import ComposableArchitecture
import VPNAppCore

extension DisconnectVPNKey {
    public static let bridgedDisconnect: @Sendable () async throws -> Void = {
        @Dependency(\.siriHelper) var siriHelper
        siriHelper().donateDisconnect()

        let gateway = Container.sharedContainer.makeVpnGateway2()
        try await gateway.disconnect()

        // todo: old VpnGateway was reloading server info after disconnect. New one does not.
        // Decide where to put this functionality and implement it!

    }
}
