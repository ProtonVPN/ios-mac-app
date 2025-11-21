//
//  Created on 28.03.2022.
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

public struct ReviewConfiguration: Equatable {
    let eligiblePlans: [String]
    let successConnections: Int
    let daysLastReviewPassed: Int
    let daysConnected: Int
    let daysFromFirstConnection: Int

    public init(eligiblePlans: [String], successConnections: Int, daysLastReviewPassed: Int, daysConnected: Int, daysFromFirstConnection: Int) {
        self.eligiblePlans = eligiblePlans
        self.successConnections = successConnections
        self.daysLastReviewPassed = daysLastReviewPassed
        self.daysConnected = daysConnected
        self.daysFromFirstConnection = daysFromFirstConnection
    }
}
