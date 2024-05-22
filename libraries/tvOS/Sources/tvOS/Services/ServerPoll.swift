//
//  Created on 30/04/2024.
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

struct ServerPollConfiguration: DependencyKey {
    let delayBeforePollingStarts: Duration
    let period: Duration
    let failAfterAttempts: Int

    static let liveValue: ServerPollConfiguration = ServerPollConfiguration(
        delayBeforePollingStarts: .seconds(5),
        period: .seconds(5),
        failAfterAttempts: 60 // ~5 minutes of polling every 5s (disregarding time to complete each request)
    )

    static let testValue = liveValue
}
