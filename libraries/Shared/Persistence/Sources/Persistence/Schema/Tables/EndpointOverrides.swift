//
//  Created on 06/01/2024.
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

import Domain
import Foundation

/// Which protocols an endpoint supports is tracked on ``Endpoint`` instead, so every
/// endpoint has a mask — even the ones that handle all protocols through one shared default address.
struct EndpointOverrides: Codable {
    let endpointId: String

    let protocolEntries: PerProtocolEntries // coding handled by GRDB
}
