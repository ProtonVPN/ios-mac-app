//
//  Created on 06/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public enum PaymentsFlowType: String, Sendable {
    case regular
    case oneClick
    case external
}

public struct PaymentTransactionFinishedEvent: Sendable {
    public let newPlanName: String?
    public let cycle: Int?
    public let offerReference: String?
    public let flowType: PaymentsFlowType?

    public init(
        newPlanName: String?,
        cycle: Int?,
        offerReference: String?,
        flowType: PaymentsFlowType?
    ) {
        self.newPlanName = newPlanName
        self.cycle = cycle
        self.offerReference = offerReference
        self.flowType = flowType
    }

    public static let webIntroFinishEvent: PaymentTransactionFinishedEvent = .init(
        newPlanName: "vpn2024", // TODO: update it to be dynamic https://protonag.atlassian.net/browse/VPNAPPL-3103
        cycle: 24,
        offerReference: "VPNINTROPRICE2024",
        flowType: .external
    )
}
