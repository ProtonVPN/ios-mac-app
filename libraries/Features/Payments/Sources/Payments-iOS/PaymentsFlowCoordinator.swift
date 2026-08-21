//
//  Created on 13/03/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import PaymentsShared
import SwiftUI
import UIKit

public enum PaymentsFlowRequest: Equatable, Sendable {
    case upsell(UpsellModalType)
    case directSubscriptionManagement
}

public enum PaymentsFlowEvent: Equatable, Sendable {
    case completed
    case dismissed
    case engaged(planId: String, purchaseType: PlanOptionV2.PlanType)
    case createAccountFirstRequested
}

/// Builds the payments screen for UIKit callers.
public final class PaymentsFlowCoordinator {
    public init() {}

    @MainActor
    public func makeViewController(
        request: PaymentsFlowRequest,
        onEvent: @escaping @Sendable @MainActor (PaymentsFlowEvent) -> Void = { _ in }
    ) -> UIViewController {
        let state: PaymentsFeature.State = switch request {
        case let .upsell(upsellModalType):
            .init(presentationKind: .upsell(upsellModalType), upsellModalType: upsellModalType)
        case .directSubscriptionManagement:
            .init(presentationKind: .directSubscriptionManagement)
        }

        let store = Store(initialState: state) {
            PaymentsFeature()
            Reduce { _, action in
                guard case let .delegate(delegate) = action else { return .none }
                let event = PaymentsFlowEvent(delegate)
                return .run { @MainActor _ in onEvent(event) }
            }
        }

        return UIHostingController(rootView: PlanOptionsViewV2TCA(store: store))
    }
}

private extension PaymentsFlowEvent {
    init(_ delegate: PaymentsFeature.Action.Delegate) {
        self = switch delegate {
        case .completed:
            .completed
        case .dismissed:
            .dismissed
        case let .engaged(planId, purchaseType):
            .engaged(planId: planId, purchaseType: purchaseType)
        case .createAccountFirstRequested:
            .createAccountFirstRequested
        }
    }
}
