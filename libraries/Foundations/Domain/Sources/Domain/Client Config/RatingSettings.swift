//
//  Created on 30.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

public struct RatingSettings: Codable, Equatable {
    public let eligiblePlans: [String]
    public let successConnections: Int
    public let daysLastReviewPassed: Int
    public let daysConnected: Int
    public let daysFromFirstConnection: Int

    init(
        eligiblePlans: [String],
        successConnections: Int,
        daysLastReviewPassed: Int,
        daysConnected: Int,
        daysFromFirstConnection: Int
    ) {
        self.eligiblePlans = eligiblePlans
        self.successConnections = successConnections
        self.daysLastReviewPassed = daysLastReviewPassed
        self.daysConnected = daysConnected
        self.daysFromFirstConnection = daysFromFirstConnection
    }

    public init() {
        self.eligiblePlans = ["vpn2022", "bundle2022", "family2022", "visionary2022", "vpnpass2023", "vpn2024", "duo2024"]
        self.successConnections = 1
        self.daysLastReviewPassed = 30
        self.daysConnected = 3
        self.daysFromFirstConnection = 0
    }
}
