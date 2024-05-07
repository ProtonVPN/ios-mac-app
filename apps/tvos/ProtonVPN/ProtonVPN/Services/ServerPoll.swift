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

struct ServerPollConfiguration: Equatable {
    let delayBeforePollingStarts: Duration
    let period: Duration
    let failAfterAttempts: Int

    static let `default` = ServerPollConfiguration(delayBeforePollingStarts: .seconds(5),
                                                   period: .seconds(1),
                                                   failAfterAttempts: 5)
    init(delayBeforePollingStarts: Duration, period: Duration, failAfterAttempts: Int) {
        self.delayBeforePollingStarts = delayBeforePollingStarts
        self.period = period
        self.failAfterAttempts = failAfterAttempts
    }
}
