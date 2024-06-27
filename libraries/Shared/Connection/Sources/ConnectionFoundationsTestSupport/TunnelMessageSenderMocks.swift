//
//  Created on 24/06/2024.
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
import XCTestDynamicOverlay
import ExtensionIPC
import ConnectionFoundations

extension TunnelMessageSender {
    public static let unimplemented: TunnelMessageSender = .init(send: { request in
        let requestErrorMessage = "Did not expect to send \(request) at this time"
        XCTFail(requestErrorMessage)
        return .error(message: requestErrorMessage)
    })

    public static func sender(
        forRequest request: WireguardProviderRequest,
        withResponse response: WireguardProviderRequest.Response,
        andOperation operation: @escaping () -> Void = { }
    ) -> TunnelMessageSender {
        return .init(send: { outgoingRequest in
            guard outgoingRequest == request else {
                let requestErrorMessage = "Did not expect to send \(request) at this time"
                XCTFail(requestErrorMessage)
                return .error(message: requestErrorMessage)
            }

            operation()

            return response
        })
    }
}
