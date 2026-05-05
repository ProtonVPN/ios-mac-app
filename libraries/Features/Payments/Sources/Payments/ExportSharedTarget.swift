//
//  Created on 05/03/2026 by Max Kupetskyi.
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

import PaymentsShared

public typealias PaymentsMainFeature = PaymentsShared.PaymentsFeature

public typealias PlanOptionV2 = PaymentsShared.PlanOptionV2
public typealias UpsellModalType = PaymentsShared.UpsellModalType
public typealias UpsellFeature = PaymentsShared.UpsellFeature
public typealias UpsellSheetFeature = PaymentsShared.UpsellSheetFeature

public typealias PaymentTransactionFinishedEvent = PaymentsShared.PaymentTransactionFinishedEvent
public typealias PaymentsFlowType = PaymentsShared.PaymentsFlowType

#if canImport(Payments_iOS)
    import Payments_iOS

    // TCA
    public typealias PaymentsMainView = Payments_iOS.PlanOptionsViewV2TCA
    public typealias PaymentsFlowCoordinator = Payments_iOS.PaymentsFlowCoordinator
    public typealias PaymentsFlowRequest = Payments_iOS.PaymentsFlowRequest
    public typealias PaymentsFlowEvent = Payments_iOS.PaymentsFlowEvent
#endif

#if canImport(Payments_macOS)
    import Payments_macOS

    public typealias UpsellViewController = Payments_macOS.UpsellViewController

    // Legacy
    public typealias LegacyUpsellFactory = Payments_macOS.LegacyUpsellFactory
#endif
