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

extension VPNSession {

    private var defaultMaxRetries: Int { 5 }

    public func send<R: ProviderRequest>(
        _ message: R,
        completion: ((Result<R.Response, ProviderMessageError>) -> Void)?
    ) {
        send(message, maxRetries: defaultMaxRetries, completion: completion)
    }

    private func send<R: ProviderRequest>(
        _ message: R,
        maxRetries: Int,
        completion: ((Result<R.Response, ProviderMessageError>) -> Void)?
    )  {
        // TODO: Retry failed messages sensibly
        fatalError("Remember to fix this!!!")
    }
}
